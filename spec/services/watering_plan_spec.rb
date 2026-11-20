require "spec_helper"

RSpec.describe WateringPlan do
  let(:now) { Time.utc(2026, 11, 20, 14, 0, 0) }
  let(:day) { 24 * 60 * 60 }
  let(:user) { User.create!(email: "plan@example.com", password: "gardening1") }
  let(:garden) { Garden.create_for!(user) }

  # Built-in plants as mock_json describes them.
  def stock(id)
    data = JSON.parse(File.read("mock_json/details/#{id}.json"), symbolize_names: true)
    PlantDetail.create!(plant_id: id, common_name: data[:common_name], details: JSON.generate(data),
                        summary: JSON.generate(cycle: data[:cycle], watering: data[:watering], collection: data[:collection],
                                               type: data[:type], drought_tolerant: data[:drought_tolerant]))
    data
  end

  def planted(id, days_ago, location: "A1", plot: garden, **attrs)
    data = stock(id) if id > 900_000 && !PlantDetail.exists?(plant_id: id)
    cell = plot.cells.find_by(location_id: location)
    cell.update!({ status: :locked, content_type: "Plant", plant_id: id, name: data && data[:common_name],
                   watering: data && data[:watering], planted_at: now - days_ago * day, last_watered_at: now - days_ago * day }.merge(attrs))
    cell
  end

  def plan(cell)
    described_class.for(cell, now: now)
  end

  it "waters a new butterfly bush every 4 days for 12 weeks, then only in long dry spells" do
    young = plan(planted(900_483, 10))
    expect(young).to include(days: 4, source: "auto", rain_resets: true, established_on: (now - 10 * day).to_date + 84)
    expect(young[:reason]).to eq("Newly planted: water regularly until it's established around #{young[:established_on].strftime('%b %-d')}")

    old = plan(planted(900_483, 90, location: "A2"))
    expect(old).to include(days: 28, reason: "Established and drought tolerant: only during long dry spells", rain_resets: true)
  end

  it "keeps annual vegetables and herbs on a short schedule" do
    expect(plan(planted(900_001, 60))).to include(days: 2, reason: "Annual: keep the soil evenly moist", established_on: nil) # tomato
    expect(plan(planted(900_002, 60, location: "A2"))).to include(days: 2) # basil
  end

  it "establishes ordinary perennials in 8 weeks and then waters them weekly" do
    hosta = planted(900_091, 30) # Foliage, Perennial, Average: an outdoor plant, not a houseplant
    expect(plan(hosta)).to include(days: 3, established_on: (now - 30 * day).to_date + 56, rain_resets: true)
    hosta.update!(planted_at: now - 60 * day)
    expect(plan(hosta)).to include(days: 7, reason: "Established: water deeply, less often")
  end

  it "treats a young tree as establishing for 12 weeks" do
    expect(plan(planted(900_464, 70))).to include(days: 3) # red maple, Average
    expect(plan(planted(900_464, 90, location: "A2"))).to include(days: 7)
  end

  it "gives succulents the dry-spell schedule once established even without the drought flag" do
    profile = { type: "Succulent", cycle: "Perennial", watering: "Minimum", drought_tolerant: false }
    expect(described_class.auto_plan(profile, "Minimum", indoor: false, planted_at: now - 100 * day, today: now.to_date)).to include(days: 28)
  end

  it "waters houseplants on their own schedule and never credits rain" do
    expect(plan(planted(900_225, 400))).to include(days: 14, rain_resets: false, established_on: nil, # snake plant
                                                  reason: "Houseplant: water when the top of the soil is dry")
    expect(described_class.auto_plan({ type: "Houseplant" }, "Frequent", indoor: false, planted_at: nil, today: now.to_date)).to include(days: 3)
  end

  it "treats anything in an indoor plot as a houseplant" do
    sunroom = Garden.create_for!(user, name: "Sunroom", indoor: true)
    expect(plan(planted(900_483, 200, plot: sunroom))).to include(days: 14, rain_resets: false, reason: "Indoors: rain never reaches it")
  end

  it "falls back to the watering category when nothing is known about the plant" do
    cell = planted(42, 3, watering: "Average", name: "Mystery")
    expect(plan(cell)).to include(days: 5, reason: "Based on its average watering needs", source: "auto")
    cell.update!(watering: "None")
    expect(plan(cell)).to include(days: nil, reason: "No regular watering needed")
  end

  it "reads type and drought tolerance from cached Perenual details when the summary lacks them" do
    PlantDetail.create!(plant_id: 77, summary: JSON.generate(cycle: "Perennial", watering: "Minimum"),
                        details: JSON.generate(type: "tree", drought_tolerant: true))
    expect(plan(planted(77, 100, watering: "Minimum"))).to include(days: 28)
  end

  it "calls Perenual's biennials biennial" do
    expect(described_class.auto_plan({ cycle: "Biannual" }, "Average", indoor: false, planted_at: nil, today: now.to_date))
      .to include(days: 4, reason: "Biennial: keep the soil evenly moist")
  end

  it "treats a perennial with no planting date as established" do
    expect(described_class.auto_plan({ cycle: "Perennial" }, "Frequent", indoor: false, planted_at: nil, today: now.to_date))
      .to include(days: 4, established_on: nil)
  end

  describe "a gardener's override" do
    it "uses their number of days" do
      cell = planted(900_483, 200, watering_override_days: 10)
      expect(plan(cell)).to include(days: 10, source: "custom", reason: "Your own schedule", rain_resets: true)
      expect(cell.next_water_at(now: now)).to eq(cell.last_watered_at + 10 * day)
    end

    it "turns reminders off with 0" do
      cell = planted(900_001, 10, watering_override_days: 0)
      expect(plan(cell)).to include(days: nil, source: "custom", reason: "Reminders turned off for this plant")
      expect(cell.tracks_watering?(now)).to be(false)
      expect(cell.needs_water?(now)).to be(false)
    end

    it "is forgotten when the cell is emptied" do
      cell = planted(900_001, 10, watering_override_days: 7)
      cell.clear!
      expect(cell.reload.watering_override_days).to be_nil
      cell.update!(watering_override_days: 3)
      cell.update!(status: :empty)
      expect(cell.reload.watering_override_days).to be_nil
    end

    it "must be a whole number of days from 0 to 60" do
      cell = planted(900_001, 10)
      expect(cell.update(watering_override_days: 61)).to be(false)
      expect(cell.update(watering_override_days: -1)).to be(false)
      expect(cell.update(watering_override_days: 2.5)).to be(false)
      expect(cell.update(watering_override_days: 60)).to be(true)
    end
  end

  it "preloads profiles and plot flags for many cells in a few queries" do
    cells = [planted(900_483, 10), planted(900_001, 10, location: "A2"), planted(900_225, 10, location: "A3")]
    fresh = garden.cells.where(location_id: %w[A1 A2 A3]).order(:location_id).to_a
    described_class.preload(fresh)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      expect(fresh.map { |c| plan(c)[:days] }).to eq([4, 2, 14])
    end
    expect(queries).to be_empty
    expect(cells.size).to eq(3)
  end

  it "looks a profile up again when the cell's plant changes" do
    cell = planted(900_001, 10)
    expect(cell.plant_profile[:type]).to eq("Vegetable")
    stock(900_225)
    cell.plant_id = 900_225
    expect(cell.plant_profile[:collection]).to eq("indoor")
  end
end
