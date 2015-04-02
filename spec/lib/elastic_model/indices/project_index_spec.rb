require "spec_helper"

describe "Project Index" do
  it "as_indexed_json should return a hash" do
    p = Project.make!
    json = p.as_indexed_json
    expect( json ).to be_a Hash
  end
end
