require "set"

# How often one planted cell wants water, in days, and why.
#
#   WateringPlan.for(cell) # => { days: 28, reason: "...", source: "auto",
#                          #      established_on: Date, rain_resets: true,
#                          #      auto_days: 28 }
#
# days nil means no reminders. The plan comes from the plant's profile (type,
# cycle, drought tolerance, built-in collection, Perenual watering level) and
# whether its plot is indoors; a gardener's per-cell override wins.
#
#   Houseplants (indoor plot, built-in indoor collection, type Houseplant):
#     Frequent 3 / Average 7 / Minimum 14. Rain never counts.
#   Annuals and biennials (most vegetables):  2 / 4 / 7.
#   Everything else outdoors (perennials, shrubs, trees, vines, grasses...):
#     establishing for 8 weeks after planting (12 for trees and shrubs): 2 / 3 / 4,
#     then 4 / 7 / 14, or 28 days when drought tolerant, a succulent or a cactus.
#   Nothing known about the plant: the old category intervals, 2 / 5 / 10.
#
# Outdoors, a day with half an inch of rain counts as a watering (see
# GardenAlerts#rain_credit), so a 28-day plan only fires after a long dry spell.
module WateringPlan
  CATEGORY_DAYS = { "Frequent" => 2, "Average" => 5, "Minimum" => 10 }.freeze
  HOUSEPLANT_DAYS = { "Frequent" => 3, "Average" => 7, "Minimum" => 14 }.freeze
  ANNUAL_DAYS = { "Frequent" => 2, "Average" => 4, "Minimum" => 7 }.freeze
  ESTABLISHING_DAYS = { "Frequent" => 2, "Average" => 3, "Minimum" => 4 }.freeze
  ESTABLISHED_DAYS = { "Frequent" => 4, "Average" => 7, "Minimum" => 14 }.freeze
  DRY_SPELL_DAYS = 28

  ESTABLISH_WEEKS = 8
  WOODY_ESTABLISH_WEEKS = 12
  WOODY_TYPES = /tree|shrub|evergreen|palm|conifer/i
  DRY_TYPES = /succulent|cactus/i

  module_function

  # cell responds to watering, watering_override_days, planted_at,
  # plant_profile and plot_indoor?.
  def for(cell, now: Time.now)
    auto = auto_plan(cell.plant_profile, cell.watering, indoor: cell.plot_indoor?, planted_at: cell.planted_at, today: now.to_date)
    override = cell.watering_override_days
    auto[:auto_days] = auto[:days]
    return auto if override.nil?

    reason = override.zero? ? "Reminders turned off for this plant" : "Your own schedule"
    auto.merge(days: override.zero? ? nil : override, reason: reason, source: "custom")
  end

  def auto_plan(profile, watering, indoor:, planted_at:, today:)
    profile ||= {}
    category = [watering, profile[:watering]].find { |w| CATEGORY_DAYS.key?(w) }
    houseplant = indoor || profile[:collection] == "indoor" || profile[:type].to_s.casecmp?("houseplant")
    plan = { days: nil, reason: "No regular watering needed", source: "auto", established_on: nil, rain_resets: !houseplant }
    return plan unless category

    if houseplant
      reason = indoor ? "Indoors: rain never reaches it" : "Houseplant: water when the top of the soil is dry"
      return plan.merge(days: HOUSEPLANT_DAYS[category], reason: reason)
    end

    cycle = profile[:cycle].to_s.downcase
    type = profile[:type].to_s
    if cycle.match?(/annual|biennial|biannual/) && !cycle.include?("perennial")
      return plan.merge(days: ANNUAL_DAYS[category], reason: "#{cycle.start_with?('bi') ? 'Biennial' : 'Annual'}: keep the soil evenly moist")
    end
    return plan.merge(days: CATEGORY_DAYS[category], reason: "Based on its #{category.downcase} watering needs") if cycle.empty? && type.empty?

    weeks = type.match?(WOODY_TYPES) ? WOODY_ESTABLISH_WEEKS : ESTABLISH_WEEKS
    established_on = planted_at && (planted_at.to_date + weeks * 7)
    plan[:established_on] = established_on
    if established_on && today < established_on
      return plan.merge(days: ESTABLISHING_DAYS[category],
                        reason: "Newly planted: water regularly until it's established around #{established_on.strftime('%b %-d')}")
    end

    if profile[:drought_tolerant] == true || type.match?(DRY_TYPES)
      plan.merge(days: DRY_SPELL_DAYS, reason: "Established and drought tolerant: only during long dry spells")
    else
      plan.merge(days: ESTABLISHED_DAYS[category], reason: "Established: water deeply, less often")
    end
  end

  # { plant_id => profile } for the given ids, in one query.
  def profiles_for(plant_ids)
    ids = plant_ids.compact.uniq
    return {} if ids.empty?

    PlantDetail.where(plant_id: ids).select(:plant_id, :summary, :details).to_h { |r| [r.plant_id, profile_from(r)] }
  end

  def profile_from(record)
    s = record.summary_hash
    d = s.key?(:type) ? {} : (record.details_hash || {})
    { type: s[:type] || d[:type], cycle: s[:cycle] || d[:cycle], watering: s[:watering] || d[:watering],
      drought_tolerant: s.key?(:drought_tolerant) ? s[:drought_tolerant] : d[:drought_tolerant], collection: s[:collection] }
  end

  # Loads plant profiles and plot indoor flags for many cells at once so
  # serializing a garden doesn't query per cell.
  def preload(cells)
    cells = Array(cells)
    profiles = profiles_for(cells.map(&:plant_id))
    indoor = Garden.where(id: cells.map(&:garden_id).compact.uniq, indoor: true).pluck(:id).to_set
    cells.each { |cell| cell.preload_watering(profiles[cell.plant_id], indoor.include?(cell.garden_id)) }
  end
end
