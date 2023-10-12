require "spec_helper"

RSpec.describe "GET /decor_items Endpoint", type: :request do
  include Rack::Test::Methods

  def app
    Backyarder
  end

  describe "GET /decor" do
    let(:query) { "barrier" }

    it "returns a 200 status and data for a valid query" do
      get "/decor?query=#{query}"

      expect(last_response.status).to eq(200)

      response_data = JSON.parse(last_response.body)
      first_item = response_data['data'].first

      expect(first_item['type']).to include("barrier")
      expect(first_item['image_url']).to be_a(String)
    end

    it "returns multiple items for a valid query with multiple matches" do
      get "/decor?query=#{query}"

      response_data = JSON.parse(last_response.body)

      expect(response_data['data'].length).to be > 1
    end
  end
end
