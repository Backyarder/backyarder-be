require "spec_helper"

RSpec.describe "Search Request", type: :request do
  # A species-list response shaped like Perenual's, built from the stock
  # snapshots so the test doesn't depend on the network.
  let(:species_list_body) do
    data = JSON.parse(File.read("mock_json/index.json"), symbolize_names: true)[:data]
    JSON.generate({ data: data, to: data.size, per_page: 30, current_page: 1, total: data.size })
  end

  let!(:species_list_stub) do
    stub_request(:get, %r{perenual\.com/api/v2/species-list})
      .with(query: hash_including("q" => "maple"))
      .to_return(status: 200, body: species_list_body, headers: { "Content-Type" => "application/json" })
  end

  let!(:thumbnail_stub) do
    stub_request(:get, %r{perenual\.com/storage/})
      .to_return(status: 200, body: "jpegbytes", headers: { "Content-Type" => "image/jpeg" })
  end

  describe "GET /search/:q" do
    it "returns list JSON with cached thumbnails and a day-long cache header" do
      get "/search/maple"

      expect(last_response).to be_ok
      expect(last_response.headers["Cache-Control"]).to include("max-age=86400")
      response = JSON.parse(last_response.body, symbolize_names: true)
      expect(response[:data]).to be_an(Array)
      expect(response[:data].count).to eq(10)

      response[:data].each do |plant|
        expect(plant[:id]).to eq(nil)
        expect(plant[:type]).to eq("list")
        attrs = plant[:attributes]
        expect(attrs[:name]).to be_a String
        expect(attrs[:plant_id]).to be_a Integer
        expect(attrs[:watering]).to be_a String
        expect(attrs[:sunlight]).to be_a Array
        expect(attrs[:content_type]).to eq("Plant")
        expect(attrs).to have_key(:hardiness)
        expect(attrs).to have_key(:type)
      end

      first = response[:data][0][:attributes]
      expect(first[:image]).to end_with("/plants/#{first[:plant_id]}/thumbnail") # mounted under /api/v1 in config.ru
      expect(PlantDetail.find_by(plant_id: first[:plant_id]).thumbnail).to eq("jpegbytes")
    end

    it "serves a repeat search from the cache without calling Perenual again" do
      get "/search/maple"
      get "/search/MAPLE"

      expect(species_list_stub).to have_been_requested.once
      expect(ApiUsage.count_today).to eq(1)
      expect(SearchCache.count).to eq(1)
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)["data"].count).to eq(10)
    end

    it "fills in type and hardiness from cached plant details when available" do
      PlantDetail.create!(plant_id: 2692, details: JSON.generate(type: "flower", hardiness: { min: "3", max: "8" }),
                          details_fetched_at: Time.now)

      get "/search/maple"

      coneflower = JSON.parse(last_response.body, symbolize_names: true)[:data]
                       .find { |p| p[:attributes][:plant_id] == 2692 }[:attributes]
      expect(coneflower[:type]).to eq("flower")
      expect(coneflower[:hardiness]).to eq({ min: "3", max: "8" })
    end

    it "returns 503 with a friendly message when Perenual rate-limits us" do
      stub_request(:get, %r{perenual\.com/api/v2/species-list}).to_return(status: 429, body: "Too Many Requests")

      get "/search/maple"

      expect(last_response.status).to eq(503)
      expect(JSON.parse(last_response.body)["error"]).to include("try again tomorrow")
    end

    it "stops calling Perenual once the daily budget is spent" do
      ApiUsage.create!(day: ApiUsage.today, count: ApiUsage.limit)

      get "/search/maple"

      expect(last_response.status).to eq(503)
      expect(species_list_stub).not_to have_been_requested
    end

    it "serves stale cached results when the budget is spent" do
      get "/search/maple"
      SearchCache.find_by(query: "maple").update_columns(updated_at: Time.now - SearchCache::TTL - 60)
      stub_request(:get, %r{perenual\.com/api/v2/species-list}).to_return(status: 429, body: "Too Many Requests")

      get "/search/maple"

      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)["data"].count).to eq(10)
    end
  end
end
