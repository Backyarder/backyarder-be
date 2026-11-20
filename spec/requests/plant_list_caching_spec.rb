require "spec_helper"

RSpec.describe "Plant data caching headers", type: :request do
  it "makes browsers revalidate the plant list and answers 304 when it has not changed" do
    get "/plants"
    expect(last_response).to be_ok
    expect(last_response.headers["Cache-Control"]).to include("no-cache")
    etag = last_response.headers["ETag"]
    expect(etag).to start_with('W/"')

    get "/plants", nil, { "HTTP_IF_NONE_MATCH" => etag }
    expect(last_response.status).to eq(304)
    expect(last_response.body).to be_empty

    get "/plants", nil, { "HTTP_IF_NONE_MATCH" => '"stale"' }
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)["data"]).not_to be_empty
  end
end
