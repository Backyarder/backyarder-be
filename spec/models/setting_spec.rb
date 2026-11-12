require "spec_helper"

RSpec.describe Setting, type: :model do
  it "stores and reads string values with a default" do
    expect(Setting.get("missing", "dflt")).to eq("dflt")
    Setting.set("k", 3)
    expect(Setting.get("k")).to eq("3")
    Setting.set("k", "4")
    expect(Setting.get("k")).to eq("4")
    expect(Setting.count).to eq(1)
  end
end
