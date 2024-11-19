require "spec_helper.rb"

describe ControlledTerm do
  elastic_models( ControlledTerm )

  it { is_expected.to have_many(:labels).class_name("ControlledTermLabel").dependent :destroy }
  it { is_expected.to have_many(:controlled_term_taxa).inverse_of(:controlled_term).dependent :destroy }
  it { is_expected.to have_many(:values).through(:controlled_term_values).source :controlled_value }
  it { is_expected.to have_many(:attrs).through(:controlled_term_value_attrs).source :controlled_attribute }
  it { is_expected.to have_many(:value_annotations).class_name("Annotation").with_foreign_key :controlled_value_id }
  it { is_expected.to belong_to :user }
  it do
    is_expected.to have_many(:attribute_annotations).class_name("Annotation").with_foreign_key :controlled_attribute_id
  end
  it do
    is_expected.to have_many(:controlled_term_values).with_foreign_key(:controlled_attribute_id)
                                                     .class_name("ControlledTermValue").dependent :destroy
  end
  it do
    is_expected.to have_many(:controlled_term_value_attrs).with_foreign_key(:controlled_value_id)
                                                     .class_name("ControlledTermValue").dependent :destroy
  end
  it do
    is_expected.to have_many(:taxa).conditions(["controlled_term_taxa.exception = ?", false])
                                   .through(:controlled_term_taxa)
  end
  it do
    is_expected.to have_many(:excepted_taxa).conditions(["controlled_term_taxa.exception = ?", true])
                                            .through(:controlled_term_taxa).source :taxon
  end

  it "validates labels" do
    expect( ControlledTerm.new ).not_to be_valid
    invalid_label = ControlledTermLabel.new
    expect( invalid_label ).not_to be_valid
    expect( ControlledTerm.new( labels: [invalid_label] ) ).not_to be_valid
    valid_label = ControlledTermLabel.new( label: "foo", definition: "bar" )
    expect( valid_label ).to be_valid
    expect( ControlledTerm.new( labels: [valid_label] ) ).to be_valid
  end

  describe "values" do
    it "returns all values for a term" do
      atr = make_controlled_term_with_label
      make_controlled_value_with_label( nil, atr )
      make_controlled_value_with_label( nil, atr )
      expect( atr.values.count ).to eq 2
    end
  end

  describe "taxon selection" do
    let(:animalia) { Taxon.make!(name: "Animalia", rank: Taxon::KINGDOM) }
    let(:mammalia) { Taxon.make!(name: "Mammalia", parent: animalia, rank: Taxon::CLASS) }
    let(:primates) { Taxon.make!(name: "Primates", parent: mammalia, rank: Taxon::ORDER) }
    let(:plantae) { Taxon.make!(name: "Plantae", rank: Taxon::KINGDOM) }
  
    describe "for_taxon" do
      it "returns terms for taxa and their ancestors" do
        make_controlled_term_with_label
        [mammalia, primates, plantae].each do |t|
          ControlledTermTaxon.make!( taxon: t )
        end
        # Animalia should have the one term that with no taxon restrictions
        expect(ControlledTerm.for_taxon(animalia).count).to eq 1
        # Mammalia should have what Animalia has plus the Mammalia one
        expect(ControlledTerm.for_taxon(mammalia).count).to eq 2
        # Primates should have what Mammalia has plus the primates one
        expect(ControlledTerm.for_taxon(primates).count).to eq 3
        # Plantae should have the one term with no restrictions plus the plant-specific one
        expect(ControlledTerm.for_taxon(plantae).count).to eq 2
      end

      it "does not return excepted descendants of the chosen taxon" do
        animalia_ct = ControlledTermTaxon.make!( taxon: animalia ).controlled_term
        mammalia_ct = ControlledTermTaxon.make!( taxon: mammalia ).controlled_term
        ct_ids_for_animalia = ControlledTerm.for_taxon( animalia ).map(&:id)
        expect( ct_ids_for_animalia ).to include animalia_ct.id
        expect( ct_ids_for_animalia ).not_to include mammalia_ct.id
      end
    end

    describe "applicable_to_taxon" do
      it "should be true for a taxon associated with this controlled term" do
        animalia_ct = ControlledTermTaxon.make!( taxon: animalia ).controlled_term
        expect( animalia_ct.applicable_to_taxon( animalia ) ).to be true
      end
      it "should be true for a descendant of the taxon associated with this controlled term" do
        animalia_ct = ControlledTermTaxon.make!( taxon: animalia ).controlled_term
        expect( animalia_ct.applicable_to_taxon( mammalia ) ).to be true
      end
      it "should be false for a descendant of the taxon associated with this controlled term if the descendant is an exception" do
        animalia_ct = ControlledTermTaxon.make!( taxon: animalia ).controlled_term
        ControlledTermTaxon.make!( taxon: mammalia, controlled_term: animalia_ct, exception: true )
        expect( animalia_ct.applicable_to_taxon( mammalia ) ).to be false
      end
      it "should be true for any taxon if the term has no associated taxa" do
        ct = make_controlled_term_with_label
        expect( ct.applicable_to_taxon( mammalia ) ).to be true
      end
    end
  end

  describe "unassigned_values" do
    it "returns an array of value terms not associated with an attribute" do
      atr = make_controlled_term_with_label
      val = make_controlled_term_with_label( nil, is_value: true )
      ControlledTermValue.make!( controlled_attribute: atr, controlled_value: val )
      unassigned = make_controlled_term_with_label( nil, is_value: true )
      expect(ControlledTerm.unassigned_values.count).to eq 1
      expect(ControlledTerm.unassigned_values.first).to eq unassigned
    end
  end

end
