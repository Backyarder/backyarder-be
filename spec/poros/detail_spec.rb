require "spec_helper"

RSpec.describe Detail, type: :poro do
  describe "initialize" do
    it "sets the attributes correctly" do
      detail_data = {
        id: 3000,
        common_name: "greenstem forsythia",
        scientific_name: [
          "Forsythia viridissima 'Bronxensis'"
        ],
        other_name: [],
        family: "Oleaceae",
        origin: [
          "China"
        ],
        type: "Deciduous shrub",
        dimension: "0.75 to 1.00 feet",
        dimensions: {
          type: nil,
          min_value: 0.75,
          max_value: 1,
          unit: ""
        },
        cycle: "Perennial",
        attracts: [],
        propagation: [
          "Cutting",
          "Layering Propagation",
          "Grafting Propagation",
          "Division",
          "Seed Propagation"
        ],
        hardiness: {
          min: "6",
          max: "8"
        },
        hardiness_location: {
          full_url: "https://perenual.com/api/hardiness-map?species_id=3000&size=og&key=sk-jltt64ecd520941142002",
          full_iframe: "<iframe frameborder=0 scrolling=yes seamless=seamless width=1000 height=550 style='margin:auto;' src='https://perenual.com/api/hardiness-map?species_id=3000&size=og&key=sk-jltt64ecd520941142002'></iframe>"
        },
        watering: "Average",
        depth_water_requirement: [],
        volume_water_requirement: [],
        watering_period: nil,
        watering_general_benchmark: {
          value: "7-10",
          unit: "days"
        },
        plant_anatomy: [
          {
            part: "flowers",
            color: [
              "yellow"
            ]
          },
          {
            part: "leaves",
            color: [
              "green"
            ]
          },
          {
            part: "stems",
            color: [
              "gray-brown"
            ]
          }
        ],
        sunlight: [
          "Full sun",
          "part shade"
        ],
        pruning_month: [
          "February",
          "March",
          "April",
          "May",
          "July",
          "December",
          "January",
          "February",
          "May",
          "June",
          "July",
          "August"
        ],
        pruning_count: {
          amount: 2,
          interval: "yearly"
        },
        seeds: 0,
        maintenance: "Low",
        "care-guides" => "http://perenual.com/api/species-care-guide-list?species_id=3000&key=sk-jltt64ecd520941142002",
        soil: [],
        growth_rate: "Low",
        drought_tolerant: true,
        salt_tolerant: false,
        thorny: false,
        invasive: false,
        tropical: false,
        indoor: false,
        care_level: "Moderate",
        pest_susceptibility: [],
        pest_susceptibility_api: "Coming Soon",
        flowers: true,
        flowering_season: nil,
        flower_color: "Yellow",
        cones: false,
        fruits: false,
        edible_fruit: false,
        edible_fruit_taste_profile: "Coming Soon",
        fruit_nutritional_value: "Coming Soon",
        fruit_color: [],
        harvest_season: nil,
        leaf: true,
        leaf_color: [
          "green"
        ],
        edible_leaf: false,
        cuisine: false,
        medicinal: false,
        poisonous_to_humans: 0,
        poisonous_to_pets: 0,
        description: "Greenstem Forsythia (Forsythia viridissima 'Bronxensis') is an amazing plant species because of its unique beauty...",
        default_image: {
          license: 5,
          license_name: "Attribution-ShareAlike License",
          license_url: "https://creativecommons.org/licenses/by-sa/2.0/",
          original_url: "https://perenual.com/storage/species_image/3000_forsythia_viridissima_bronxensis/og/26170857033_214e4fbb27_b.jpg",
          regular_url: "https://perenual.com/storage/species_image/3000_forsythia_viridissima_bronxensis/regular/26170857033_214e4fbb27_b.jpg",
          medium_url: "https://perenual.com/storage/species_image/3000_forsythia_viridissima_bronxensis/medium/26170857033_214e4fbb27_b.jpg",
          small_url: "https://perenual.com/storage/species_image/3000_forsythia_viridissima_bronxensis/small/26170857033_214e4fbb27_b.jpg",
          thumbnail: "https://perenual.com/storage/species_image/3000_forsythia_viridissima_bronxensis/thumbnail/26170857033_214e4fbb27_b.jpg"
        },
        other_images: "Upgrade Plan To Supreme For Access https://perenual.com/subscription-api-pricing. Im sorry"
      }

      detail = Detail.new(detail_data)

      expect(detail.id).to be_nil
      expect(detail.plant_id).to eq(3000)
      expect(detail.image).to eq("https://perenual.com/storage/species_image/3000_forsythia_viridissima_bronxensis/regular/26170857033_214e4fbb27_b.jpg")
      expect(detail.name).to eq("greenstem forsythia")
      expect(detail.scientific_name).to eq(["Forsythia viridissima 'Bronxensis'"])
      expect(detail.type).to eq("Deciduous shrub")
      expect(detail.leaf_color).to eq(["green"])
      expect(detail.cycle).to eq("Perennial")
      expect(detail.watering).to eq("Average")
      expect(detail.sunlight).to eq(["Full sun", "part shade"])
      expect(detail.hardiness).to eq({ :min=>"6", :max=>"8" })
      expect(detail.section).to be_nil
      expect(detail.pruning_month).to eq(["February", "March", "April", "May", "July", "December", "January", "February", "May", "June", "July", "August"])
      expect(detail.attracts).to eq([])
      expect(detail.flowering_season).to eq([])
      expect(detail.edible_fruit).to eq(false)
      expect(detail.maintenance).to eq("Low")
      expect(detail.poisonous_to_pets).to eq(false)
      expect(detail.drought_tolerant).to eq(true)
      expect(detail.invasive).to eq(false)
      expect(detail.indoor).to eq(false)
    end
  end
end
