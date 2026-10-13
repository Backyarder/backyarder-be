class SearchCache < ActiveRecord::Base
  TTL = 7 * 24 * 60 * 60

  validates :query, presence: true, uniqueness: true

  def fresh?
    updated_at > Time.now - TTL
  end

  def results_array
    JSON.parse(results, symbolize_names: true)
  end
end
