require "spec_helper"

RSpec.describe DecorItem do
  describe '#initialize' do
    it 'creates a decor item from given attributes' do
      attributes = {
        image_url: 'https://example.com/fence.jpg',
        name: 'A beautiful wooden fence',
        type: 'barrier'
      }
      decor_item = DecorItem.new(attributes)

      expect(decor_item.image_url).to eq('https://example.com/fence.jpg')
      expect(decor_item.name).to eq('A beautiful wooden fence')
      expect(decor_item.type).to eq('barrier')
    end
  end
end
