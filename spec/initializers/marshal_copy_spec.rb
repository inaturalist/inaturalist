require File.expand_path("../../spec_helper", __FILE__)

describe "Array" do
  before do
    @array = [ 1, 2, 3, 4 ]
  end

  it "should create an identical marshal_copy" do
    expect( @array.marshal_copy ).to eq @array
  end

  it "should points to a different instance in memory" do
    copy = @array.marshal_copy
    copy << 5
    expect( copy.length ).to_not be @array.length
    expect( copy ).to_not be @array
  end

end

describe "Hash" do

  before do
    @hash = { one: [ ], two: [ ] }
  end

  it "should create an identical marshal_copy" do
    expect( @hash.marshal_copy ).to eq @hash
  end

  it "should points to a different instance in memory" do
    copy = @hash.marshal_copy
    copy[:one] << :something
    expect( copy[:one].length).not_to eq @hash.length
    expect( copy ).to_not be @hash
  end

end
