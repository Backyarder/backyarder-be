require "spec_helper"

RSpec.describe DecorItem do
  describe '#initialize' do
    it 'creates a decor item from given attributes' do
      decor_data = {
        image: 'https://example.com/fence.jpg',
        name: 'Wooden Fence',
        type: 'barrier'
      }

      decor_item = DecorItem.new(decor_data[:image], decor_data[:name], decor_data[:type])

      expect(decor_item.id).to be_nil
      expect(decor_item.type).to eq('list')
      expect(decor_item.attributes[:image]).to eq('https://example.com/fence.jpg')
      expect(decor_item.attributes[:name]).to eq('Wooden Fence')
      expect(decor_item.attributes[:type]).to eq('barrier')
    end
  end
end
