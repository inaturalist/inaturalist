require "spec_helper"

describe "Delayed::Jobs serialization" do

  it "adds an dj_serialize_minimal attribute to models" do
    o = Observation.make!
    expect( o.dj_serialize_minimal ).to be_nil
    o.dj_serialize_minimal = true
    expect( o.dj_serialize_minimal ).to be true
  end

  it "serializes only primary key when dj_serialize_minimal is set" do
    o = Observation.make!
    expect( YAML.load( o.to_yaml ).attributes.length ).to be > 30
    o.dj_serialize_minimal = true
    # This is a little brittle, but when you deserialize and instantiate a ruby
    # object, you might end up with more attributes than were actually
    # serialized to YAML. This test at least tries to ensure that the hydrated
    # object is at least minimal
    expect( YAML.load( o.to_yaml ).attributes.length ).to be < 5
  end

end
