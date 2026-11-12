require "spec_helper"

RSpec.describe "Accounts", type: :request do
  def body
    JSON.parse(last_response.body, symbolize_names: true)
  end

  describe "POST /auth/signup" do
    it "creates the user, signs them in with a cookie and returns a token" do
      post "/auth/signup", JSON.generate(email: "New@Example.com", password: "gardening1"), json_headers

      expect(last_response.status).to eq(201)
      expect(body[:data][:attributes][:email]).to eq("new@example.com")
      expect(body[:token]).to be_a(String)
      expect(last_response.headers["Set-Cookie"]).to include("backyarder_session=", "HttpOnly", "SameSite=Lax")

      get "/auth/me", nil, { "HTTP_COOKIE" => "backyarder_session=#{body[:token]}" }
      expect(last_response).to be_ok
      expect(body[:data][:attributes][:email]).to eq("new@example.com")
    end

    it "looks up the hardiness zone when a zip code is given" do
      stub_hardiness("30501")

      post "/auth/signup", JSON.generate(email: "zip@example.com", password: "gardening1", zip_code: "30501"), json_headers

      expect(last_response.status).to eq(201)
      expect(body[:data][:attributes]).to include(zip_code: "30501", hardiness_zone: "8a")
      expect(User.last.latitude).to be_within(0.001).of(34.306643)
    end

    it "rejects an unknown zip code, a bad email and a short password" do
      stub_unknown_zip("00000")
      post "/auth/signup", JSON.generate(email: "zip@example.com", password: "gardening1", zip_code: "00000"), json_headers
      expect(last_response.status).to eq(422)
      expect(body[:error]).to include("Zip code could not be found")

      post "/auth/signup", JSON.generate(email: "nope", password: "gardening1"), json_headers
      expect(last_response.status).to eq(422)
      expect(body[:error]).to include("Email is invalid")

      post "/auth/signup", JSON.generate(email: "ok@example.com", password: "short"), json_headers
      expect(last_response.status).to eq(422)
      expect(body[:error]).to include("Password is too short")

      expect(User.count).to eq(0)
    end

    it "rejects a duplicate email" do
      create_user("dup@example.com")
      post "/auth/signup", JSON.generate(email: "DUP@example.com", password: "gardening1"), json_headers

      expect(last_response.status).to eq(422)
      expect(body[:error]).to include("Email has already been taken")
    end

    it "gives the first account the pre-existing shared garden" do
      shared = Garden.create!(name: "Shared garden")
      shared.seed_cells!
      shared.cells.find_by(location_id: "B2").update!(status: :locked, name: "Fern", plant_id: 1, content_type: "Plant")

      post "/auth/signup", JSON.generate(email: "first@example.com", password: "gardening1"), json_headers
      get "/garden", nil, auth_headers(User.find_by(email: "first@example.com"))
      names = body[:data].map { |c| c[:attributes][:name] }.compact
      expect(names).to eq(["Fern"])

      post "/auth/signup", JSON.generate(email: "second@example.com", password: "gardening1"), json_headers
      get "/garden", nil, auth_headers(User.find_by(email: "second@example.com"))
      expect(body[:data].length).to eq(100)
      expect(body[:data].map { |c| c[:attributes][:name] }.compact).to be_empty
    end
  end

  describe "POST /auth/login and DELETE /auth/logout" do
    it "signs in with the right password and ends the session on logout" do
      user = create_user("login@example.com")

      post "/auth/login", JSON.generate(email: "LOGIN@example.com", password: "gardening1"), json_headers
      expect(last_response).to be_ok
      token = body[:token]
      expect(Session.authenticate(token).user).to eq(user)

      delete "/auth/logout", nil, { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
      expect(last_response.status).to eq(204)
      expect(last_response.headers["Set-Cookie"]).to include("backyarder_session=;")
      expect(Session.authenticate(token)).to be_nil

      get "/auth/me", nil, { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
      expect(last_response.status).to eq(401)
    end

    it "rejects a wrong password or unknown email without saying which" do
      create_user("login@example.com")

      post "/auth/login", JSON.generate(email: "login@example.com", password: "wrong"), json_headers
      expect(last_response.status).to eq(401)
      post "/auth/login", JSON.generate(email: "ghost@example.com", password: "gardening1"), json_headers
      expect(last_response.status).to eq(401)
      expect(body[:error]).to eq("Email or password is incorrect.")
      expect(Session.count).to eq(0)
    end

    it "returns 400 for a non-JSON body" do
      post "/auth/login", "email=x", json_headers
      expect(last_response.status).to eq(400)
    end
  end

  describe "PATCH /auth/me" do
    it "saves a zip code with its zone and clears it when blank" do
      user = create_user
      stub_hardiness("30501", zone: "8a")

      patch "/auth/me", JSON.generate(zip_code: "30501"), json_headers(user)
      expect(last_response).to be_ok
      expect(body[:data][:attributes]).to include(zip_code: "30501", hardiness_zone: "8a")

      patch "/auth/me", JSON.generate(zip_code: ""), json_headers(user)
      expect(body[:data][:attributes]).to include(zip_code: nil, hardiness_zone: nil)
      expect(user.reload.latitude).to be_nil
    end

    it "keeps the old zip when the new one is unknown" do
      user = create_user
      user.update!(zip_code: "30501", hardiness_zone: "8a")
      stub_unknown_zip("99999")

      patch "/auth/me", JSON.generate(zip_code: "99999"), json_headers(user)

      expect(last_response.status).to eq(422)
      expect(user.reload.zip_code).to eq("30501")
    end

    it "requires a login" do
      patch "/auth/me", JSON.generate(zip_code: "30501"), json_headers
      expect(last_response.status).to eq(401)
    end
  end

  describe "garden scoping" do
    it "keeps each user's garden separate and refuses anonymous access" do
      alice = create_user("alice@example.com")
      bob = create_user("bob@example.com")
      alice.garden.cells.find_by(location_id: "A1").update!(status: :locked, name: "Rose", plant_id: 1, content_type: "Plant", watering: :Average)

      get "/garden", nil, auth_headers(alice)
      expect(body[:data].first[:attributes][:name]).to eq("Rose")

      get "/garden", nil, auth_headers(bob)
      expect(body[:data].length).to eq(100)
      expect(body[:data].first[:attributes][:name]).to be_nil

      patch "/cell", JSON.generate(action: "water", location_id: "A1"), json_headers(bob)
      expect(last_response).to be_ok
      expect(alice.garden.cells.find_by(location_id: "A1").last_watered_at).to be_nil

      delete "/all", nil, auth_headers(bob)
      expect(alice.garden.cells.find_by(location_id: "A1").name).to eq("Rose")

      %w[/garden /garden-stats /wishlist].each do |path|
        get path
        expect(last_response.status).to eq(401), path
      end
      patch "/cell", JSON.generate(action: "water", location_id: "A1"), json_headers
      expect(last_response.status).to eq(401)
      delete "/garden"
      expect(last_response.status).to eq(401)
    end

    it "returns 404 for a location that is not in the grid" do
      user = create_user
      patch "/cell", JSON.generate(action: "water", location_id: "Z9"), json_headers(user)
      expect(last_response.status).to eq(404)
    end
  end

  describe "wishlist" do
    it "adds, lists and removes plants per user" do
      user = create_user
      other = create_user("other@example.com")

      post "/wishlist", JSON.generate(plant_id: 42), json_headers(user)
      expect(last_response.status).to eq(201)
      post "/wishlist", JSON.generate(plant_id: 42), json_headers(user)
      post "/wishlist", JSON.generate(plant_id: 7), json_headers(user)

      get "/wishlist", nil, auth_headers(user)
      expect(body[:data].map { |i| i[:attributes][:plant_id] }).to eq([42, 7])

      get "/wishlist", nil, auth_headers(other)
      expect(body[:data]).to be_empty

      delete "/wishlist/42", nil, auth_headers(user)
      expect(last_response.status).to eq(204)
      get "/wishlist", nil, auth_headers(user)
      expect(body[:data].map { |i| i[:attributes][:plant_id] }).to eq([7])

      post "/wishlist", JSON.generate(plant_id: "abc"), json_headers(user)
      expect(last_response.status).to eq(422)
    end
  end
end
