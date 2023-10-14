require "spec_helper"

RSpec.describe "GET /decor_items Endpoint", type: :request do
  describe "GET /decor" do
    xit "returns a 200 status and data for a valid query" do
      get "/decor"

      expect(last_response.status).to eq(200)

      response_data = JSON.parse(last_response.body)
    end
  end
end
