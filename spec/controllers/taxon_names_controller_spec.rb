require File.dirname(__FILE__) + '/../spec_helper'

describe TaxonNamesController, "update" do
  it "should allow a non-curator to change a name they made to another lexicon" do
    user = create :user
    tn = create :taxon_name, creator: user, lexicon: TaxonName::SPANISH
    sign_in user
    put :update, params: { id: tn.id, taxon_name: { lexicon: TaxonName::ENGLISH } }
    tn.reload
    expect( tn.lexicon ).to eq TaxonName::ENGLISH
  end

  it "should not allow a non-curator to change a name they made to a scientific name" do
    user = create :user
    tn = create :taxon_name, creator: user, lexicon: TaxonName::ENGLISH
    expect( tn.lexicon ).not_to eq TaxonName::SCIENTIFIC_NAMES
    sign_in user
    put :update, params: { id: tn.id, taxon_name: { lexicon: TaxonName::SCIENTIFIC_NAMES, is_valid: false } }
    tn.reload
    expect( tn.lexicon ).not_to eq TaxonName::SCIENTIFIC_NAMES
  end
end

describe TaxonNamesController, "destroy" do
  it "should work for curators" do
    tn = TaxonName.make!( lexicon: TaxonName::LEXICONS[:ENGLISH] )
    u = make_curator
    sign_in u
    delete :destroy, params: { id: tn.id }
    expect( TaxonName.find_by_id( tn.id ) ).to be_blank
  end
  it "should work for the user who made the name" do
    u = User.make!
    tn = TaxonName.make!( creator: u, lexicon: TaxonName::LEXICONS[:ENGLISH] )
    sign_in u
    delete :destroy, params: { id: tn.id }
    expect( TaxonName.find_by_id( tn.id ) ).to be_blank
  end
  it "should not work for non-curators who didn't make the name" do
    tn = TaxonName.make!( creator: User.make!, lexicon: TaxonName::LEXICONS[:ENGLISH] )
    u = User.make!
    sign_in u
    delete :destroy, params: { id: tn.id }
    expect( TaxonName.find_by_id( tn.id ) ).not_to be_blank
  end
end
