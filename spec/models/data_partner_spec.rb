require "spec_helper.rb"

describe DataPartner, "validation" do
  it { is_expected.to validate_inclusion_of(:frequency).in_array(described_class::FREQUENCIES).allow_blank }
  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_presence_of :url }
  it { is_expected.to validate_presence_of :description }

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
