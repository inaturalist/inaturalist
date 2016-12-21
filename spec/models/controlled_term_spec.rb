require "spec_helper.rb"

describe ControlledTerm do

  describe "values" do
    it "returns all values for a term" do
      atr = ControlledTerm.make!
      ControlledTermValue.make!(controlled_attribute: atr)
      ControlledTermValue.make!(controlled_attribute: atr)
      expect(atr.values.count).to eq 2
    end
  end

  describe "for_taxon" do
    it "returns terms for taxa and their ancestors" do
      animalia = Taxon.make!(name: "Animalia")
      mammalia = Taxon.make!(name: "Mammalia", parent: animalia)
      primates = Taxon.make!(name: "Primates", parent: mammalia)
      plantae = Taxon.make!(name: "Plantae")
      AncestryDenormalizer.denormalize
      ControlledTerm.make!
      ControlledTerm.make!(valid_within_taxon: mammalia)
      ControlledTerm.make!(valid_within_taxon: primates)
      ControlledTerm.make!(valid_within_taxon: plantae)
      expect(ControlledTerm.for_taxon(animalia).count).to eq 1
      expect(ControlledTerm.for_taxon(mammalia).count).to eq 2
      expect(ControlledTerm.for_taxon(primates).count).to eq 3
      expect(ControlledTerm.for_taxon(plantae).count).to eq 2
    end
  end

  describe "unassigned_values" do
    it "returns an array of value terms not associated with an attribute" do
      atr = ControlledTerm.make!
      val = ControlledTerm.make!(is_value: true)
      ControlledTermValue.make!(controlled_attribute: atr, controlled_value: val)
      unassigned = ControlledTerm.make!(is_value: true)
      expect(ControlledTerm.unassigned_values.count).to eq 1
      expect(ControlledTerm.unassigned_values.first).to eq unassigned
    end
  end

end
