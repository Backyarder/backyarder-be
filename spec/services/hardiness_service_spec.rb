require "spec_helper"

RSpec.describe HardinessService do
  it "returns the zone and coordinates for a known zip" do
    stub_hardiness("30501", zone: "8a", lat: "34.306643", lon: "-83.82352")

    expect(described_class.new.lookup("30501")).to eq(zone: "8a", latitude: 34.306643, longitude: -83.82352)
  end

  it "returns nil for an unknown zip, a malformed zip or a failing service" do
    stub_unknown_zip("00000")
    stub_request(:get, "https://phzmapi.org/11111.json").to_return(status: 200, body: "not json")

    expect(described_class.new.lookup("00000")).to be_nil
    expect(described_class.new.lookup("1234")).to be_nil
    expect(described_class.new.lookup("11111")).to be_nil
  end
end
