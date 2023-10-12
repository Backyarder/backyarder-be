require 'spec_helper'
require_relative '../../app/facades/decor_items_facade'

RSpec.describe DecorItemsFacade do
  describe '.get_decor_items' do
    it 'returns a DecorItem object for a valid query' do
      mock_response = {
        results: [
          {
            alt_description: 'A beautiful wooden fence',
            urls: { regular: 'https://example.com/fence.jpg' }
          }
        ]
      }

      allow(UnsplashService).to receive(:get_images).and_return(mock_response)

      decor_item = DecorItemsFacade.get_decor_items('fence')

      expect(decor_item).to be_an_instance_of(DecorItem)
      expect(decor_item.attributes[:image]).to eq('https://example.com/fence.jpg')
      expect(decor_item.attributes[:name]).to eq('A beautiful wooden fence')
      expect(decor_item.attributes[:type]).to eq('barrier')
    end


    it 'returns nil for an empty service response' do
      mock_response = { results: [] }

      allow(UnsplashService).to receive(:get_images).and_return(mock_response)

      decor_item = DecorItemsFacade.get_decor_items('invalid_query')

      expect(decor_item).to be_nil
    end
  end
end
