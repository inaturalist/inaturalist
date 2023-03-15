# frozen_string_literal: true

require "spec_helper"

describe DarwinCore::VernacularName do
  let( :taxon_name_without_lexicon ) do
    taxon_name = create :taxon_name
    TaxonName.where( id: taxon_name.id ).update_all( "lexicon = null" )
    taxon_name.reload
    expect( taxon_name.lexicon ).to be_nil
    taxon_name
  end

  describe "language" do
    it "should be und if lexicon is null" do
      expect( DarwinCore::VernacularName.adapt( taxon_name_without_lexicon ).language ).to eq "und"
    end
  end

  describe "data" do
    it "should include records without a lexicon" do
      taxon_name = taxon_name_without_lexicon
      expect( taxon_name.taxon ).to be_is_active
      expect( taxon_name.lexicon ).to be_blank
      paths = DarwinCore::VernacularName.data( core: DarwinCore::Cores::TAXON )
      puts "paths: #{paths}"
      row = CSV.read( paths.first, headers: true ).first
      expect( row["vernacularName"] ).to eq taxon_name.name
      expect( row["language"] ).to eq "und"
    end
  end
end
