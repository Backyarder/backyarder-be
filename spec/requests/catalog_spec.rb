require "spec_helper"

RSpec.describe "Catalogue snapshot", type: :request do
  def page_body(page, ids, last_page:)
    data = ids.map { |id| { id: id, common_name: "Plant #{id}", cycle: "Perennial", watering: "Average", sunlight: ["full sun"], default_image: { thumbnail: "https://perenual.com/storage/#{id}.jpg" } } }
    JSON.generate(data: data, current_page: page, last_page: last_page, per_page: 30, total: 60)
  end

  before do
    ENV["CRON_SECRET"] = "s3cret"
  end
  after { ENV.delete("CRON_SECRET") }

  let!(:page1) { stub_request(:get, %r{perenual\.com/api/v2/species-list}).with(query: hash_including("page" => "1")).to_return(status: 200, body: page_body(1, [1, 2, 3], last_page: 2), headers: { "Content-Type" => "application/json" }) }
  let!(:page2) { stub_request(:get, %r{perenual\.com/api/v2/species-list}).with(query: hash_including("page" => "2")).to_return(status: 200, body: page_body(2, [4, 5, 3001], last_page: 2), headers: { "Content-Type" => "application/json" }) }

  it "walks the pages, remembers free-tier plants with thumbnails, and stops when done" do
    post "/plants/catalog?pages=1", nil, { "HTTP_X_CRON_SECRET" => "s3cret" }
    expect(last_response).to be_ok
    status = JSON.parse(last_response.body, symbolize_names: true)
    expect(status).to include(done: false, next_page: 2, pages_done: 1, plants_known: 3)
    expect(PlantDetail.find_by(plant_id: 2).thumbnail).to eq("imagebytes")
    expect(PlantDetail.find_by(plant_id: 2).listing).to include(name: "Plant 2", watering: "Average", has_image: true)

    post "/plants/catalog?pages=10", nil, { "HTTP_X_CRON_SECRET" => "s3cret" }
    status = JSON.parse(last_response.body, symbolize_names: true)
    expect(status).to include(done: true, pages_done: 1, plants_known: 5)
    expect(PlantDetail.find_by(plant_id: 3001)).to be_nil

    post "/plants/catalog?pages=10", nil, { "HTTP_X_CRON_SECRET" => "s3cret" }
    expect(JSON.parse(last_response.body, symbolize_names: true)).to include(done: true)
    expect(page1).to have_been_requested.once
    expect(page2).to have_been_requested.once
    expect(ApiUsage.count_today).to eq(2)

    get "/search/plant"
    expect(ApiUsage.count_today).to eq(2), "search is local now"
  end

  it "leaves a reserve of calls for users" do
    ApiUsage.create!(day: ApiUsage.today, count: ApiUsage.limit - PlantCache::CATALOG_RESERVE)

    post "/plants/catalog?pages=5", nil, { "HTTP_X_CRON_SECRET" => "s3cret" }

    expect(JSON.parse(last_response.body, symbolize_names: true)).to include(pages_done: 0, done: false)
    expect(page1).not_to have_been_requested
  end

  it "requires the secret and reports status publicly" do
    post "/plants/catalog"
    expect(last_response.status).to eq(401)

    get "/plants/catalog"
    expect(last_response).to be_ok
    expect(JSON.parse(last_response.body, symbolize_names: true)).to include(done: false, next_page: 1, plants_known: 0)
  end
end
