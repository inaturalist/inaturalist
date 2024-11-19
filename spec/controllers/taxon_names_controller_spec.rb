require File.dirname(__FILE__) + '/../spec_helper'

describe TaxonNamesController do
  let( :user ) { User.make! }
  let( :audit_comment ) { "an audit comment is required" }

  describe "create" do
    it "should create taxon names" do
      taxon = Taxon.make!
      before_names_count = taxon.taxon_names.count
      sign_in user
      post :create, params: { taxon_id: taxon.id, taxon_name: {
        taxon_id: taxon.id,
        name: "newname",
        lexicon: TaxonName::ENGLISH,
        audit_comment: audit_comment
      } }
      taxon.reload
      expect( taxon.taxon_names.count ).to eq( before_names_count + 1 )
    end

    it "should record audit comments" do
      taxon = Taxon.make!
      before_names_count = taxon.taxon_names.count
      sign_in user
      post :create, params: { taxon_id: taxon.id, taxon_name: {
        taxon_id: taxon.id,
        name: "newname",
        lexicon: TaxonName::ENGLISH,
        audit_comment: audit_comment
      } }
      taxon.reload
      expect( Audited::Audit.where(
        associated_type: "Taxon",
        associated_id: taxon.id,
        comment: audit_comment
      ).any? ).to eq true
    end

    it "should fail to create if audit_comment is missing" do
      taxon = Taxon.make!
      before_names_count = taxon.taxon_names.count
      sign_in user
      post :create, params: { taxon_id: taxon.id, taxon_name: {
        taxon_id: taxon.id,
        name: "newname",
        lexicon: TaxonName::ENGLISH
      } }
      taxon.reload
      expect( taxon.taxon_names.count ).to eq( before_names_count )
    end
  end

  describe "update" do
    it "should allow a non-curator to change a name they made to another lexicon" do
      tn = create :taxon_name, creator: user, lexicon: TaxonName::SPANISH
      sign_in user
      put :update, params: { id: tn.id, taxon_name: {
        lexicon: TaxonName::ENGLISH,
        audit_comment: audit_comment
      } }
      tn.reload
      expect( tn.lexicon ).to eq TaxonName::ENGLISH
    end

    it "should not allow a non-curator to change a name they made to a scientific name" do
      tn = create :taxon_name, creator: user, lexicon: TaxonName::ENGLISH
      expect( tn.lexicon ).not_to eq TaxonName::SCIENTIFIC_NAMES
      sign_in user
      put :update, params: { id: tn.id, taxon_name: {
        lexicon: TaxonName::SCIENTIFIC_NAMES,
        is_valid: false,
        audit_comment: audit_comment
      } }
      tn.reload
      expect( tn.lexicon ).not_to eq TaxonName::SCIENTIFIC_NAMES
    end

    it "should record audit comments" do
      tn = create :taxon_name, creator: user, lexicon: TaxonName::SPANISH
      sign_in user
      put :update, params: { id: tn.id, taxon_name: {
        lexicon: TaxonName::ENGLISH,
        audit_comment: audit_comment
      } }
      tn.reload
      expect( Audited::Audit.where(
        associated_type: "Taxon",
        associated_id: tn.taxon_id,
        comment: audit_comment
      ).any? ).to eq true
    end

    it "should not update some name attributes when there is no audit_comment" do
      tn = create :taxon_name, creator: user, lexicon: TaxonName::ENGLISH
      expect( tn.lexicon ).not_to eq TaxonName::SCIENTIFIC_NAMES
      sign_in user
      put :update, params: { id: tn.id, taxon_name: {
        lexicon: TaxonName::SCIENTIFIC_NAMES,
        is_valid: false
      } }
      tn.reload
      expect( tn.lexicon ).not_to eq TaxonName::SCIENTIFIC_NAMES
    end

    it "does not require audit comment if only position is changed" do
      tn = create :taxon_name, creator: user, lexicon: TaxonName::ENGLISH, position: 1
      sign_in user
      put :update, params: { id: tn.id, taxon_name: {
        position: 2,
      } }
      tn.reload
      expect( tn.position ).to eq 2
    end

    it "does not require audit comment if only place name position is changed" do
      tn = create :taxon_name, creator: user, lexicon: TaxonName::ENGLISH, position: 1
      place = make_place_with_geom
      ptn = PlaceTaxonName.make!( place: place, taxon_name: tn )
      sign_in user
      put :update, params: { id: tn.id, taxon_name: {
        place_taxon_names_attributes: {
          "0": {
            id: ptn.id,
            position: 2
          }
        }
      } }
      ptn.reload
      expect( ptn.position ).to eq 2
    end
  end

  describe "destroy" do
    it "should work for curators" do
      tn = TaxonName.make!( lexicon: TaxonName::LEXICONS[:ENGLISH] )
      u = make_curator
      sign_in u
      delete :destroy, params: { id: tn.id, taxon_name: {
        audit_comment: audit_comment
      } }
      expect( TaxonName.find_by_id( tn.id ) ).to be_blank
    end

    it "should work for the user who made the name" do
      tn = TaxonName.make!(
        creator: user,
        lexicon: TaxonName::LEXICONS[:ENGLISH]
      )
      sign_in user
      delete :destroy, params: { id: tn.id, taxon_name: {
        audit_comment: audit_comment
      } }
      expect( TaxonName.find_by_id( tn.id ) ).to be_blank
    end

    it "should not work for non-curators who didn't make the name" do
      tn = TaxonName.make!(
        creator: User.make!,
        lexicon: TaxonName::LEXICONS[:ENGLISH]
      )
      sign_in user
      delete :destroy, params: { id: tn.id, taxon_name: {
        audit_comment: "an audit comment is required"
      } }
      expect( TaxonName.find_by_id( tn.id ) ).not_to be_blank
    end

    it "should record audit comments" do
      tn = TaxonName.make!(
        creator: user,
        lexicon: TaxonName::LEXICONS[:ENGLISH]
      )
      sign_in user
      delete :destroy, params: { id: tn.id, taxon_name: {
        audit_comment: audit_comment
      } }
      expect( Audited::Audit.where(
        associated_type: "Taxon",
        associated_id: tn.taxon_id,
        comment: audit_comment
      ).any? ).to eq true
    end

    it "should not work if audit_comment is missind" do
      tn = TaxonName.make!(
        creator: user,
        lexicon: TaxonName::LEXICONS[:ENGLISH]
      )
      sign_in user
      delete :destroy, params: { id: tn.id }
      expect( TaxonName.find_by_id( tn.id ) ).to_not be_blank
    end
  end
end
