require "spec_helper"

describe "Taxon Index" do
  it "as_indexed_json should return a hash" do
    t = Taxon.make!
    json = t.as_indexed_json
    expect( json ).to be_a Hash
  end
end
