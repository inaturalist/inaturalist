# frozen_string_literal: true

require "spec_helper"

describe TaxaHelper do
  describe "common_taxon_names" do
    it "should return a name from translations if taxon is iconic and there are no other valid names" do
      life = create( :taxon, name: "Life", rank: Taxon::STATEOFMATTER )
      expect( life ).not_to be_blank
      expect( life.taxon_names.where( lexicon: TaxonName::HUNGARIAN ) ).not_to exist
      name_from_translations = I18n.t( :life, scope: "all_taxa", locale: "hu" )
      expect( name_from_translations ).not_to be_blank
      expect( common_taxon_names( life, locale: "hu" ).first ).to eq name_from_translations
    end
  end
end
