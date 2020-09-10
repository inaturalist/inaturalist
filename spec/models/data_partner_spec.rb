# encoding: UTF-8
require File.dirname(__FILE__) + "/../spec_helper.rb"

describe DataPartner, "validation" do
  it "should pass if dwca_params freq is allowed" do
    dp = DataPartner.make( dwca_params: { freq: DataPartner::MONTHLY } )
    expect( dp ).to be_valid
    expect( dp.errors[:dwca_params] ).to be_blank
  end
  it "should fail if dwca_params freq is not allowed" do
    dp = DataPartner.make( dwca_params: { freq: "foo" } )
    expect( dp ).not_to be_valid
    expect( dp.errors[:dwca_params] ).not_to be_blank
  end
end
