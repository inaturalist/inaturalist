require "spec_helper"

describe TaxonChange do
  describe "move_input_children_to_output" do
    it "does not raise an error if target taxon rank_level is nil" do
      tc = TaxonChange.make!( taxon: Taxon.make!, user: make_admin )
      t = Taxon.make!( rank: "nonsense", rank_level: nil )
      expect {
        tc.move_input_children_to_output( t )
      }.to_not raise_error
    end
  end
end

