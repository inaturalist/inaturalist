require "spec_helper"

# using Observation in these specs since it includes FieldsChangedAt
describe "FieldsChangedAt" do

  it "creates change records" do
    expect( ModelAttributeChange.count ).to be 0
    o = Observation.make!
    o.update_attributes(place_guess: "pg", observed_on_string: "1954-3-21")
    expect( ModelAttributeChange.count ).to be 2
  end

  it "creates one record per field" do
    expect( ModelAttributeChange.count ).to be 0
    o = Observation.make!
    10.times do |i|
      o.update_attributes(place_guess: "pg#{i}", observed_on_string: "1954-3-#{i}")
    end
    expect( ModelAttributeChange.count ).to be 2
  end

  it "destroys the change records on destroy" do
    expect( ModelAttributeChange.count ).to be 0
    o = Observation.make!
    o.update_attributes(place_guess: "pg", observed_on_string: "1954-3-21")
    expect( ModelAttributeChange.count ).to be 2
    o.destroy
    expect( ModelAttributeChange.count ).to be 0
  end

end
