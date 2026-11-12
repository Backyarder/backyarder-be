# Tiny key/value store for operational state (e.g. how far the catalogue
# snapshot has got).
class Setting < ActiveRecord::Base
  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end

  def self.set(key, value)
    row = find_or_initialize_by(key: key)
    row.update!(value: value.to_s)
    value
  end
end
