require File.dirname(__FILE__) + '/../spec_helper'

describe TaxonNamesController, "destroy" do
  it "should work for curators" do
    tn = TaxonName.make!( lexicon: TaxonName::LEXICONS[:ENGLISH] )
    u = make_curator
    sign_in u
    delete :destroy, id: tn.id
    expect( TaxonName.find_by_id( tn.id ) ).to be_blank
  end
  it "should work for the user who made the name" do
    u = User.make!
    tn = TaxonName.make!( creator: u, lexicon: TaxonName::LEXICONS[:ENGLISH] )
    sign_in u
    delete :destroy, id: tn.id
    expect( TaxonName.find_by_id( tn.id ) ).to be_blank
  end
  it "should not work for non-curators who didn't make the name" do
    tn = TaxonName.make!( creator: User.make!, lexicon: TaxonName::LEXICONS[:ENGLISH] )
    u = User.make!
    sign_in u
    delete :destroy, id: tn.id
    expect( TaxonName.find_by_id( tn.id ) ).not_to be_blank
  end
end
