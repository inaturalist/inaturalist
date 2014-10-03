require File.expand_path("../../spec_helper", __FILE__)

describe 'Array' do

  before do
    @array = [ 1, 2, 3, 4 ]
  end

  it "should create an identical marshal_copy" do
    @array.marshal_copy.should == @array
  end

  it "should points to a different instance in memory" do
    copy = @array.marshal_copy
    copy << 5
    copy.length.should_not == @array.length
    copy.should_not == @array
  end

end

describe 'Hash' do

  before do
    @hash = { one: [ ], two: [ ] }
  end

  it "should create an identical marshal_copy" do
    @hash.marshal_copy.should == @hash
  end

  it "should points to a different instance in memory" do
    copy = @hash.marshal_copy
    copy[:one] << :something
    copy[:one].length.should_not == @hash.length
    copy.should_not == @hash
  end

end
