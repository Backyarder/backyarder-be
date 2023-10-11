require 'spec_helper'

RSpec.describe UnsplashService do
  it ".get_images", :vcr do
    VCR.use_cassette("unsplash_search_fence") do
      images = UnsplashService.get_images('fence')

      expect(images).to be_a Hash
      expect(images).to have_key :results

      images[:results].each do |image|
        expect(image).to have_key :alt_description
        expect(image).to have_key :urls
        expect(image[:urls]).to have_key :regular
      end
    end
  end
end