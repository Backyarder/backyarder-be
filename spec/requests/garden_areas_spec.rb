require "spec_helper"

RSpec.describe "Garden areas", type: :request do
  let(:user) { create_user }
  let(:day) { 24 * 60 * 60 }

  def body
    JSON.parse(last_response.body, symbolize_names: true)
  end

  def send_json(verb, path, payload = {})
    send(verb, path, JSON.generate(payload), json_headers(user).merge(auth_headers(user)))
  end

  it "lists the first area, creating it on first use" do
    get "/gardens", nil, auth_headers(user)

    expect(last_response).to be_ok
    expect(body[:data].map { |g| g[:attributes].slice(:name, :indoor, :plant_count, :needs_water_count) })
      .to eq([{ name: "My Garden", indoor: false, plant_count: 0, needs_water_count: 0 }])
  end

  it "creates, renames, flags indoor and deletes areas" do
    get "/gardens", nil, auth_headers(user)
    send_json(:post, "/gardens", name: "  Back porch  ", indoor: true)

    expect(last_response).to be_ok
    porch = body[:data]
    expect(porch[:attributes]).to include(name: "Back porch", indoor: true, position: 1)
    expect(Garden.find(porch[:id]).cells.count).to eq(100)

    send_json(:patch, "/gardens/#{porch[:id]}", name: "Sunroom", indoor: false)
    expect(body[:data].map { |g| g[:attributes][:name] }).to eq(["My Garden", "Sunroom"])
    expect(Garden.find(porch[:id]).indoor).to be(false)

    send_json(:delete, "/gardens/#{porch[:id]}")
    expect(body[:data].map { |g| g[:attributes][:name] }).to eq(["My Garden"])
  end

  it "names an unnamed area and rejects bad names" do
    send_json(:post, "/gardens", {})
    expect(body[:data][:attributes][:name]).to eq("New plot")

    send_json(:post, "/gardens", name: "x" * 41)
    expect(last_response.status).to eq(422)

    send_json(:patch, "/gardens/#{user.garden.id}", name: " ")
    expect(last_response.status).to eq(422)
    expect(body[:error]).to include("Name")
  end

  it "keeps at least one area and caps how many there are" do
    send_json(:delete, "/gardens/#{user.garden.id}")
    expect(last_response.status).to eq(422)

    (Garden::MAX_PER_USER - 1).times { |i| Garden.create_for!(user, name: "Area #{i}") }
    send_json(:post, "/gardens", name: "One too many")
    expect(last_response.status).to eq(422)
    expect(body[:error]).to include("up to #{Garden::MAX_PER_USER}")
  end

  it "never touches another user's areas" do
    other = create_user("neighbour@example.com")
    theirs = Garden.create_for!(other, name: "Theirs")

    send_json(:patch, "/gardens/#{theirs.id}", name: "Mine now")
    expect(last_response.status).to eq(404)
    send_json(:delete, "/gardens/#{theirs.id}")
    expect(last_response.status).to eq(404)
    get "/garden?garden_id=#{theirs.id}", nil, auth_headers(user)
    expect(last_response.status).to eq(404)
    expect(theirs.reload.name).to eq("Theirs")
  end

  it "reads and changes cells in the area named by garden_id" do
    first = user.garden
    porch = Garden.create_for!(user, name: "Porch", indoor: true)

    send_json(:patch, "/cell", garden_id: porch.id, location_id: "B2", status: 3, plant_id: 42, name: "Fern", content_type: "Plant", watering: 3)
    expect(last_response).to be_ok

    expect(porch.cells.find_by(location_id: "B2").name).to eq("Fern")
    expect(first.cells.find_by(location_id: "B2").name).to be_nil

    get "/garden?garden_id=#{porch.id}", nil, auth_headers(user)
    expect(body[:data].find { |c| c[:attributes][:location_id] == "B2" }[:attributes][:name]).to eq("Fern")
    get "/garden", nil, auth_headers(user)
    expect(body[:data].find { |c| c[:attributes][:location_id] == "B2" }[:attributes][:name]).to be_nil

    delete "/all?garden_id=#{porch.id}", nil, auth_headers(user)
    expect(porch.cells.find_by(location_id: "B2").name).to be_nil
  end

  it "counts plants and plants due per area" do
    user.garden
    porch = Garden.create_for!(user, name: "Porch", indoor: true)
    user.garden.cells.find_by(location_id: "A1").update!(status: :locked, name: "Tomato", plant_id: 1, content_type: "Plant", watering: :Frequent, planted_at: Time.now - 9 * day)
    porch.cells.find_by(location_id: "A1").update!(status: :placed, name: "Fern", plant_id: 2, content_type: "Plant", watering: :Average)

    get "/gardens", nil, auth_headers(user)

    expect(body[:data].map { |g| g[:attributes].slice(:name, :plant_count, :needs_water_count) })
      .to eq([{ name: "My Garden", plant_count: 1, needs_water_count: 1 }, { name: "Porch", plant_count: 1, needs_water_count: 0 }])
  end
end
