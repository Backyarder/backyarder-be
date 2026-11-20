require "spec_helper"

RSpec.describe "Kitchen garden (built-in plants)", type: :request do
  it "lists the kitchen plants with the stock plants, marked by collection, without Perenual" do
    get "/plants"

    expect(last_response).to be_ok
    data = JSON.parse(last_response.body, symbolize_names: true)[:data]
    kitchen = data.select { |p| p[:attributes][:collection] == "kitchen" }
    stock = data.reject { |p| p[:attributes][:collection] }
    by_collection = data.map { |p| p[:attributes][:collection] }.compact.tally
    expect(stock.size).to eq(30)
    expect(by_collection).to eq("kitchen" => 165, "flowers" => 134, "trees" => 162, "succulents" => 30, "indoor" => 67)
    tomato = kitchen.find { |p| p[:attributes][:name] == "tomato" }[:attributes]
    expect(tomato).to include(plant_id: 900001, watering: "Frequent", type: "Vegetable", content_type: "Plant", image: "/images/plants/900001.jpg")
    expect(tomato[:hardiness]).to eq({ min: "2", max: "11" })
    expect(ApiUsage.count_today).to eq(0)
  end

  it "serves details and care notes for a kitchen plant from the snapshot" do
    get "/plants/900001"

    expect(last_response).to be_ok
    attrs = JSON.parse(last_response.body, symbolize_names: true)[:data][:attributes]
    expect(attrs[:name]).to eq("tomato")
    expect(attrs[:image]).to eq("/images/plants/900001.jpg")
    expect(attrs[:image_credit].keys).to contain_exactly(:author, :license, :license_url, :source_url)
    expect(attrs[:image_credit][:source_url]).to start_with("https://commons.wikimedia.org/wiki/File:")
    expect(attrs[:section].map { |s| s[:type] }).to eq(%w[watering sunlight pruning])
    expect(attrs[:section].first[:description]).to include("Water deeply")
    expect(attrs[:poisonous_to_pets]).to be(true) # tomato plants are toxic to pets (ASPCA)
    expect(ApiUsage.count_today).to eq(0)
    expect(PlantDetail.count).to eq(0), "built-ins are not cached rows"

    get "/plants/900001/thumbnail"
    expect(last_response.status).to eq(404)
    get "/plants/999999"
    expect(last_response.status).to eq(502)
  end

  it "is searchable locally once the stock has been imported" do
    PlantDetail.import_stock!
    stub = stub_request(:get, %r{perenual\.com/api/v2/species-list}).to_return(status: 200, body: JSON.generate(data: []), headers: { "Content-Type" => "application/json" })

    get "/search/basil"
    results = JSON.parse(last_response.body, symbolize_names: true)[:data].map { |p| p[:attributes] }
    expect(results.map { |r| r[:name] }).to eq(["basil", "Thai basil"])
    expect(results.first).to include(collection: "kitchen", image: "/images/plants/900002.jpg", watering: "Frequent")

    get "/search/pepper"
    names = JSON.parse(last_response.body, symbolize_names: true)[:data].map { |p| p[:attributes][:name] }
    expect(names).to include("bell pepper", "chili pepper")
    expect(names).to include("jalapeño pepper", "habanero pepper")
    expect(stub).to have_been_requested.times(1) # "basil" is thin locally; "pepper" has enough local matches to skip Perenual
  end

  it "serves flowers and trees with care notes, toxicity and edibility" do
    data = JSON.parse(File.read("mock_json/index.json"), symbolize_names: true)[:data]
    ids = data.select { |p| p[:collection] }.to_h { |p| [p[:common_name], p[:id]] }

    get "/plants/#{ids['peach tree']}"
    peach = JSON.parse(last_response.body, symbolize_names: true)[:data][:attributes]
    expect(peach).to include(name: "peach tree", type: "Fruit", edible_fruit: true, poisonous_to_pets: true, image: "/images/plants/900116.jpg")
    expect(peach[:section].map { |s| s[:type] }).to eq(%w[watering sunlight pruning])

    get "/plants/#{ids['hosta']}"
    hosta = JSON.parse(last_response.body, symbolize_names: true)[:data][:attributes]
    expect(hosta).to include(sunlight: ["part shade"], poisonous_to_pets: true)

    get "/plants/#{ids['snake plant']}"
    snake = JSON.parse(last_response.body, symbolize_names: true)[:data][:attributes]
    expect(snake).to include(type: "Houseplant", indoor: true, poisonous_to_pets: true, image: "/images/plants/900225.jpg")

    get "/plants/#{ids['tomato']}"
    expect(JSON.parse(last_response.body, symbolize_names: true)[:data][:attributes][:poisonous_to_pets]).to be(true)

    get "/plants/#{ids['black-eyed Susan']}"
    expect(JSON.parse(last_response.body, symbolize_names: true)[:data][:attributes][:hardiness]).to eq({ min: "3", max: "9" })
    expect(ApiUsage.count_today).to eq(0)
  end

  it "has complete, sane data for every built-in plant" do
    data = JSON.parse(File.read("mock_json/index.json"), symbolize_names: true)[:data].select { |p| p[:collection] }
    expect(data.map { |p| p[:common_name] }.uniq.size).to eq(data.size)
    data.each do |entry|
      d = JSON.parse(File.read("mock_json/details/#{entry[:id]}.json"), symbolize_names: true)
      expect(%w[Minimum Average Frequent]).to include(d[:watering]), entry[:common_name]
      expect(d[:hardiness][:min].to_i).to be <= d[:hardiness][:max].to_i
      expect(d[:care_sections].size).to eq(3)
      expect(d[:care_sections].map { |s| s[:description].length }.min).to be > 20
      thumb = d.dig(:default_image, :thumbnail)
      expect(entry.dig(:default_image, :thumbnail)).to eq(thumb)
      # A Wikimedia Commons photo (public domain or Creative Commons, credited), or the old icon.
      photo = thumb == "/images/plants/#{entry[:id]}.jpg"
      expect(photo || File.basename(thumb).match?(/\A[a-z]+\.svg\z/)).to be(true), entry[:common_name]
      expect(d.key?(:image_credit)).to eq(photo)
      expect([0, 1]).to include(d[:poisonous_to_pets])
      next unless photo

      expect(d[:image_credit][:license]).to match(/\A(CC0|CC BY|Public domain)/), entry[:common_name]
      expect(d[:image_credit][:author]).to be_present
      expect(d[:image_credit][:source_url]).to start_with("https://commons.wikimedia.org/wiki/File:")
    end
  end

  it "backfills watering for a kitchen plant placed from search without calling Perenual" do
    user = create_user
    Garden.create!(user: user, name: "Test").cells.create!(location_id: "A1", status: :empty)

    patch "/cell", JSON.generate(name: "tomato", content_type: "Plant", location_id: "A1", image: "/images/kitchen/tomato.svg", status: 1, plant_id: 900001), json_headers(user)

    expect(last_response).to be_ok
    expect(Cell.find_by(location_id: "A1").watering).to eq("Frequent")
    expect(ApiUsage.count_today).to eq(0)
  end
end
