# frozen_string_literal: true

require "spec_helper"

describe "TaxonDescribers" do
  describe "Eol" do
    let( :vulpes ) { Taxon.make!( name: "Vulpes" ) }
    let( :eol ) { TaxonDescribers::Eol.new }

    it "describes a taxon" do
      txt = eol.describe( vulpes )
      expect( txt ).not_to be_blank
    end
  end
end
