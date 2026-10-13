require "spec_helper"

RSpec.describe "Plant detail caching", type: :request do
  describe "GET /plants/:id" do
    it "calls Perenual twice the first time and not at all afterwards" do
      VCR.use_cassette("plant_show") do
        get "/plants/225"
        expect(last_response).to be_ok
        expect(last_response.headers["Cache-Control"]).to include("max-age=86400")
        expect(ApiUsage.count_today).to eq(2)

        get "/plants/225"
        expect(last_response).to be_ok
        expect(ApiUsage.count_today).to eq(2)
      end

      record = PlantDetail.find_by(plant_id: 225)
      expect(record.details_hash[:common_name]).to be_a String
      expect(record.care_sections).to be_an Array
    end

    it "refreshes only the details (one call) once the signed image URLs are stale" do
      VCR.use_cassette("plant_show") do
        get "/plants/225"
      end
      PlantDetail.find_by(plant_id: 225).update_columns(details_fetched_at: Time.now - PlantDetail::IMAGE_TTL - 60)

      VCR.use_cassette("plant_show") do
        get "/plants/225"
      end

      expect(last_response).to be_ok
      expect(ApiUsage.count_today).to eq(3)
    end

    it "serves stale details when the budget is gone" do
      VCR.use_cassette("plant_show") do
        get "/plants/225"
      end
      PlantDetail.find_by(plant_id: 225).update_columns(details_fetched_at: Time.now - PlantDetail::IMAGE_TTL - 60)
      ApiUsage.find_by(day: ApiUsage.today).update!(count: ApiUsage.limit)

      get "/plants/225"

      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body, symbolize_names: true)[:data][:attributes][:plant_id]).to eq(225)
    end

    it "returns 503 for an unseen plant when the budget is gone" do
      ApiUsage.create!(day: ApiUsage.today, count: ApiUsage.limit)

      get "/plants/999"

      expect(last_response.status).to eq(503)
      expect(JSON.parse(last_response.body)["error"]).to be_a String
    end

    it "returns 502 when Perenual answers with garbage" do
      stub_request(:get, %r{perenual\.com/api/v2/species/details/42}).to_return(status: 200, body: "<html>nope</html>")

      get "/plants/42"

      expect(last_response.status).to eq(502)
    end
  end

  describe "GET /plants/:id/thumbnail" do
    it "serves a stored thumbnail with a year-long cache header" do
      PlantDetail.create!(plant_id: 7, thumbnail: "jpegbytes", thumbnail_content_type: "image/jpeg")

      get "/plants/7/thumbnail"

      expect(last_response).to be_ok
      expect(last_response.headers["Content-Type"]).to eq("image/jpeg")
      expect(last_response.headers["Cache-Control"]).to include("max-age=31536000")
      expect(last_response.body).to eq("jpegbytes")
      expect(ApiUsage.count_today).to eq(0)
    end

    it "fetches details, downloads and stores the thumbnail on a miss" do
      stub_request(:get, %r{perenual\.com/api/v2/species/details/9})
        .to_return(status: 200, body: JSON.generate(id: 9, common_name: "Nine", default_image: { thumbnail: "https://perenual.com/storage/9/thumb.jpg" }),
                   headers: { "Content-Type" => "application/json" })
      stub_request(:get, %r{perenual\.com/api/species-care-guide-list})
        .to_return(status: 200, body: JSON.generate(data: [{ section: [] }]), headers: { "Content-Type" => "application/json" })
      stub_request(:get, "https://perenual.com/storage/9/thumb.jpg")
        .to_return(status: 200, body: "ninebytes", headers: { "Content-Type" => "image/jpeg" })

      get "/plants/9/thumbnail"
      expect(last_response).to be_ok
      expect(last_response.body).to eq("ninebytes")

      get "/plants/9/thumbnail"
      expect(ApiUsage.count_today).to eq(1) # details only; the care guide is not fetched for a thumbnail
    end

    it "returns 404 when the plant has no image" do
      PlantDetail.create!(plant_id: 11, details: JSON.generate(id: 11, default_image: nil), care: "[]", details_fetched_at: Time.now)

      get "/plants/11/thumbnail"

      expect(last_response.status).to eq(404)
    end
  end

  describe "PATCH /cell watering backfill" do
    let(:placement) do
      { name: "Nine", content_type: "Plant", location_id: "A1", image: "x", status: 1, plant_id: 9 }
    end

    before { Cell.create!(location_id: "A1", status: :empty) }

    it "fills watering from cached details without calling Perenual" do
      PlantDetail.create!(plant_id: 9, details: JSON.generate(id: 9, watering: "Frequent"), details_fetched_at: Time.now)

      patch "/cell", JSON.generate(placement), "CONTENT_TYPE" => "application/json"

      expect(last_response).to be_ok
      expect(Cell.find_by(location_id: "A1").watering).to eq("Frequent")
      expect(ApiUsage.count_today).to eq(0)
    end

    it "fetches details once for an unknown plant" do
      stub_request(:get, %r{perenual\.com/api/v2/species/details/9})
        .to_return(status: 200, body: JSON.generate(id: 9, watering: "Average"), headers: { "Content-Type" => "application/json" })

      patch "/cell", JSON.generate(placement), "CONTENT_TYPE" => "application/json"

      expect(Cell.find_by(location_id: "A1").watering).to eq("Average")
      expect(ApiUsage.count_today).to eq(1)
    end

    it "still places the plant when the budget is gone" do
      ApiUsage.create!(day: ApiUsage.today, count: ApiUsage.limit)

      patch "/cell", JSON.generate(placement), "CONTENT_TYPE" => "application/json"

      expect(last_response).to be_ok
      cell = Cell.find_by(location_id: "A1")
      expect(cell.status).to eq("placed")
      expect(cell.watering).to be_nil
    end

    it "keeps a watering value sent by the client" do
      patch "/cell", JSON.generate(placement.merge(watering: 1)), "CONTENT_TYPE" => "application/json"

      expect(Cell.find_by(location_id: "A1").watering).to eq("Minimum")
      expect(ApiUsage.count_today).to eq(0)
    end
  end

  describe "Perenual rate-limit reporting" do
    it "records the remaining count from a 429 body and blocks further calls until reset" do
      reset = Time.now.utc.to_i + 3600
      stub_request(:get, %r{perenual\.com/api/v2/species-list}).to_return(
        status: 429, body: JSON.generate("X-RateLimit-Limit" => 100, "X-RateLimit-Remaining" => 0, "X-RateLimit-Reset" => reset)
      )

      get "/search/fern"
      expect(last_response.status).to eq(503)
      expect(ApiUsage.remaining).to eq(0)

      get "/search/moss"
      expect(last_response.status).to eq(503)
      expect(a_request(:get, %r{species-list})).to have_been_made.once

      body = JSON.parse(last_response.body)
      get "/perenual-usage"
      usage = JSON.parse(last_response.body)
      expect(usage["perenual_reported_remaining"]).to eq(0)
      expect(usage["perenual_reset_at"]).to include(Time.at(reset).utc.strftime("%Y-%m-%dT%H:%M"))
    end

    it "uses X-RateLimit headers from successful responses when present" do
      stub_request(:get, %r{perenual\.com/api/v2/species-list}).to_return(
        status: 200, body: JSON.generate(data: []),
        headers: { "Content-Type" => "application/json", "X-RateLimit-Remaining" => "7", "X-RateLimit-Reset" => (Time.now.utc.to_i + 3600).to_s }
      )

      get "/search/fern"

      expect(last_response).to be_ok
      expect(ApiUsage.remaining).to eq(7)
    end
  end

  describe "GET /perenual-usage" do
    it "reports today's budget" do
      ApiUsage.create!(day: ApiUsage.today, count: 4)

      get "/perenual-usage"

      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body[:count]).to eq(4)
      expect(body[:limit]).to eq(ApiUsage.limit)
      expect(body[:remaining]).to eq(ApiUsage.limit - 4)
    end
  end
end
