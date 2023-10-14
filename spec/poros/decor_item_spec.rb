require "spec_helper"

RSpec.describe DecorItem do
  describe '#initialize' do
    it 'creates a decor item from given attributes' do
      attributes = {
        :id => nil,
        :type => "list",
        :attributes => {
          :image_url => "https://images.unsplash.com/photo-1627740282267-542a295da59e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w1MTM1NDh8MHwxfGFsbHx8fHx8fHx8fDE2OTY4NzQ4Mjd8&ixlib=rb-4.0.3&q=80&w=200",
          :name => "Wood Pile",
          :type => "barrier",
          :content_type => "Decor"
        }
      }

      decor_item = DecorItem.new(attributes)

      expect(decor_item.image_url).to eq('https://images.unsplash.com/photo-1627740282267-542a295da59e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w1MTM1NDh8MHwxfGFsbHx8fHx8fHx8fDE2OTY4NzQ4Mjd8&ixlib=rb-4.0.3&q=80&w=200')
      expect(decor_item.name).to eq('Wood Pile')
      expect(decor_item.type).to eq('barrier')
      expect(decor_item.content_type).to eq('Decor')
    end
  end
end
