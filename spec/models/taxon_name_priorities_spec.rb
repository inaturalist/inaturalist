require "spec_helper.rb"

describe TaxonNamePriority do

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :place }

  describe "uniqueness validations" do
    subject { TaxonNamePriority.make!( lexicon: "english" ) }
    it { is_expected.to validate_uniqueness_of( :position ).scoped_to( :user_id ) }
    it { is_expected.to validate_uniqueness_of( :lexicon ).scoped_to( :user_id, :place_id ) }
  end

  describe "creation" do
    it "should create with the next highest position" do
      u = User.make!
      tnp1 = TaxonNamePriority.make!( user: u, lexicon: "l1" )
      expect( tnp1.position ).to be 0
      tnp2 = TaxonNamePriority.make!( user: u, lexicon: "l2" )
      expect( tnp2.position ).to be 1
      tnp3 = TaxonNamePriority.make!( user: u, lexicon: "l3", position: 100 )
      expect( tnp3.position ).to be 100
      tnp4 = TaxonNamePriority.make!( user: u, lexicon: "l4" )
      expect( tnp4.position ).to be 101
    end
  end

end
