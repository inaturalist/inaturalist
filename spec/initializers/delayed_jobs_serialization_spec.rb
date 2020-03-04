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
    expect( YAML.load( o.to_yaml ).attributes.length ).to be 1
  end

end
