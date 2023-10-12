require 'spec_helper'
require_relative '../../app/facades/decor_items_facade'

RSpec.describe DecorItemsFacade do
  describe '.get_decor_items' do
    it 'returns a DecorItem object for a valid query' do
      mock_response = {
        data: [
          {
            id: nil,
            type: 'list',
            attributes: {
              image_url: 'https://example.com/fence.jpg',
              name: 'A beautiful wooden fence',
              type: 'barrier'
            }
          }
        ]
      }

      decor_items = DecorItemsFacade.get_decor_items(mock_response[:data])

      expect(decor_items).to be_an_instance_of(Array)
      expect(decor_items.length).to eq(1)

      decor_item = decor_items.first

      expect(decor_item).to be_an_instance_of(DecorItem)
      expect(decor_item.image_url).to eq('https://example.com/fence.jpg')
      expect(decor_item.name).to eq('A beautiful wooden fence')
      expect(decor_item.type).to eq('barrier')
    end

    it 'returns an empty array for an empty input' do
      decor_items = DecorItemsFacade.get_decor_items([])

      expect(decor_items).to be_an_instance_of(Array)
      expect(decor_items).to be_empty
    end
  end
end