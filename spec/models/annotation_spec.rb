# frozen_string_literal: true

require "spec_helper"

describe Annotation do
  elastic_models( ControlledTerm )

  it { is_expected.to belong_to :resource }
  it { is_expected.to belong_to( :controlled_attribute ).class_name "ControlledTerm" }
  it { is_expected.to belong_to( :controlled_value ).class_name "ControlledTerm" }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :observation_field_value }

  it { is_expected.to validate_presence_of :resource }
  it { is_expected.to validate_presence_of :controlled_attribute }

  it do
    is_expected.to validate_uniqueness_of( :controlled_value_id ).
      scoped_to :resource_type, :resource_id, :controlled_attribute_id
  end

  it "validates existence of resource" do
    expect do
      Annotation.make!( resource: nil, resource_type: "Observation", resource_id: 9999 )
    end.to raise_error( ActiveRecord::RecordInvalid, /Resource can't be blank/ )
  end

  it "validates attribute is an attribute" do
    atr = make_controlled_term_with_label( nil, is_value: true )
    expect { Annotation.make!( controlled_attribute: atr ) }.to raise_error(
      ActiveRecord::RecordInvalid, /Controlled attribute must be an attribute/
    )
  end

  it "validates value is a value" do
    val = make_controlled_term_with_label( nil )
    expect { Annotation.make!( controlled_value: val ) }.to raise_error(
      ActiveRecord::RecordInvalid, /Controlled value must be a value/
    )
  end

  it "validates attribute belongs to value" do
    expect do
      Annotation.make!(
        controlled_attribute: make_controlled_term_with_label,
        controlled_value: make_controlled_term_with_label( nil, is_value: true )
      )
    end.to raise_error( ActiveRecord::RecordInvalid, /Controlled value must belong to attribute/ )
  end

  it "validates attribute belongs to taxon" do
    animalia = Taxon.make!( name: "Animalia", rank: Taxon::KINGDOM )
    mammalia = Taxon.make!( name: "Mammalia", parent: animalia, rank: Taxon::CLASS )
    obs = Observation.make!( taxon: animalia )
    atr = make_controlled_term_with_label
    ControlledTermTaxon.make!( taxon: mammalia, controlled_term: atr )
    make_controlled_value_with_label( nil, atr )
    expect do
      Annotation.make!(
        resource: obs,
        controlled_attribute: atr,
        controlled_value: atr.values.first
      )
    end.to raise_error( ActiveRecord::RecordInvalid, /Controlled attribute must belong to taxon/ )
  end

  it "validates value belongs to taxon" do
    animalia = Taxon.make!( name: "Animalia", rank: Taxon::KINGDOM )
    mammalia = Taxon.make!( name: "Mammalia", parent: animalia, rank: Taxon::CLASS )
    obs = Observation.make!( taxon: animalia )
    atr = make_controlled_term_with_label
    val = make_controlled_term_with_label( nil, is_value: true )
    ControlledTermTaxon.make!( taxon: mammalia, controlled_term: val )
    ControlledTermValue.make!( controlled_attribute: atr, controlled_value: val )
    atr.reload
    val.reload
    expect do
      Annotation.make!(
        resource: obs,
        controlled_attribute: atr,
        controlled_value: val
      )
    end.to raise_error( ActiveRecord::RecordInvalid, /Controlled value must belong to taxon/ )
  end

  it "validates against presence of another annotation of a blocking value" do
    obs = Observation.make!
    atr = make_controlled_term_with_label( nil, multivalued: true )
    val = make_controlled_term_with_label( nil, is_value: false )
    atr.controlled_term_values.create( controlled_value: val )
    blocking_val = make_controlled_term_with_label( nil, is_value: true, blocking: true )
    atr.controlled_term_values.create( controlled_value: blocking_val )
    atr.reload
    _blocking_annotation = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: blocking_val,
      resource: obs
    )
    expect do
      Annotation.make!(
        controlled_attribute: atr,
        controlled_value: val,
        resource: obs
      )
    end.to raise_error( ActiveRecord::RecordInvalid, /blocked by another value/ )
  end

  it "validates against presence of another annotation if this is a blocking value" do
    obs = Observation.make!
    atr = make_controlled_term_with_label( nil, multivalued: true )
    val = make_controlled_term_with_label( nil, is_value: true )
    atr.controlled_term_values.create( controlled_value: val )
    blocking_val = make_controlled_term_with_label( nil, is_value: true, blocking: true )
    atr.controlled_term_values.create( controlled_value: blocking_val )
    atr.reload
    val.reload
    blocking_val.reload
    Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val,
      resource: obs
    )
    expect do
      Annotation.make!(
        controlled_attribute: atr,
        controlled_value: blocking_val,
        resource: obs
      )
    end.to raise_error( ActiveRecord::RecordInvalid, /is blocking but another annotation already added/ )
  end

  it "validates for multivalued term on update" do
    obs = Observation.make!
    atr = make_controlled_term_with_label( nil, multivalued: true )
    val1 = make_controlled_term_with_label( nil, is_value: true )
    val2 = make_controlled_term_with_label( nil, is_value: true )
    atr.controlled_term_values.create( controlled_value: val1 )
    atr.controlled_term_values.create( controlled_value: val2 )
    atr.reload
    a1 = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val1,
      resource: obs
    )
    expect( a1 ).to be_valid
    a2 = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val2,
      resource: obs
    )
    expect( a2 ).to be_valid
    a1.reload
    expect( a1 ).to be_valid
  end

  it "creates valid instances" do
    controlled_attribute = make_controlled_term_with_label
    controlled_value = make_controlled_value_with_label( nil, controlled_attribute )
    expect do
      Annotation.make!(
        controlled_attribute: controlled_attribute,
        controlled_value: controlled_value
      )
    end.to_not raise_error
    expect( Annotation.count ).to eq 1
  end

  it "does not allow multiple values per attribute unless specified" do
    atr = make_controlled_term_with_label( nil, multivalued: false )
    val1 = make_controlled_term_with_label( nil, is_value: true )
    val2 = make_controlled_term_with_label( nil, is_value: true )
    atr.controlled_term_values.create( controlled_value: val1 )
    atr.controlled_term_values.create( controlled_value: val2 )
    atr.reload
    original = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val1
    )
    expect do
      Annotation.make!(
        resource: original.resource,
        controlled_attribute: atr,
        controlled_value: val2
      )
    end.to raise_error( ActiveRecord::RecordInvalid, /Controlled attribute cannot have multiple values/ )
  end

  it "does allow multiple values per attribute if specified" do
    atr = make_controlled_term_with_label( nil, multivalued: true )
    val1 = make_controlled_term_with_label( nil, is_value: true )
    val2 = make_controlled_term_with_label( nil, is_value: true )
    atr.controlled_term_values.create( controlled_value: val1 )
    atr.controlled_term_values.create( controlled_value: val2 )
    atr.reload
    val1.reload
    val1.reload
    original = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val1
    )
    expect do
      Annotation.make!(
        resource: original.resource,
        controlled_attribute: atr,
        controlled_value: val2
      )
    end.to_not raise_error
  end

  describe "creation" do
    it "should touch the resource" do
      o = Observation.make!
      t = o.created_at
      a = make_annotation( resource: o )
      a.save!
      o.reload
      expect( o.updated_at ).to be > t
    end
  end

  describe "deletion" do
    it "should touch the resource" do
      o = Observation.make!
      a = make_annotation( resource: o )
      a.save!
      t = o.updated_at
      a.destroy
      o.reload
      expect( o.updated_at ).to be > t
    end
  end

  describe "deletion after" do
    before do
      @attribute = make_controlled_term_with_label
      @value = make_controlled_term_with_label( nil, is_value: true )
      @attribute.controlled_term_values << ControlledTermValue.new(
        controlled_attribute: @attribute,
        controlled_value: @value
      )
      @family = Taxon.make!( rank: Taxon::FAMILY )
      @genus = Taxon.make!( rank: Taxon::GENUS, parent: @family )
      @species = Taxon.make!( rank: Taxon::SPECIES, parent: @genus )
      @attribute.controlled_term_taxa.create!( taxon: @family )

      @value.reload
      @attribute.reload
      @observation = Observation.make!( taxon: @genus )
      @annotation = Annotation.make!(
        resource: @observation,
        controlled_attribute: @attribute,
        controlled_value: @value
      )
    end
    describe "changing the observation taxon" do
      it "should happen when the taxon is no longer a descendant of the controlled term taxon" do
        @observation.update( taxon: Taxon.make!, editing_user_id: @observation.user_id )
        expect( Annotation.find_by_id( @annotation.id ) ).to be_blank
      end
      it "should not happen if the taxon is still a descendant of the controlled term taxon" do
        @observation.update( taxon: @species )
        expect( Annotation.find_by_id( @annotation.id ) ).not_to be_blank
      end
    end
    describe "moving the observation taxon" do
      it "should happen when the taxon is no longer a descendant of the controlled term taxon" do
        other_family = Taxon.make!( rank: Taxon::FAMILY )
        @observation.taxon.update( parent: other_family )
        Delayed::Worker.new.work_off
        expect( Annotation.find_by_id( @annotation.id ) ).to be_blank
      end
      it "should not happen if the taxon is still a descendant of the controlled term taxon" do
        subfamily = Taxon.make!( rank: Taxon::SUBFAMILY, parent: @family )
        @observation.taxon.update( parent: subfamily )
        Delayed::Worker.new.work_off
        expect( Annotation.find_by_id( @annotation.id ) ).not_to be_blank
      end
    end
    describe "changing the controlled term taxon" do
      it "should happen when the observation taxon is no longer a descendant of the controlled term taxon" do
        @attribute.controlled_term_taxa.destroy_all
        @attribute.controlled_term_taxa.create!( taxon: Taxon.make! )
        Delayed::Worker.new.work_off
        expect( Annotation.find_by_id( @annotation.id ) ).to be_blank
      end
      it "should not happen if the observation taxon is still a descendant of the controlled term taxon" do
        subfamily = Taxon.make!( rank: Taxon::SUBFAMILY, parent: @family )
        @attribute.controlled_term_taxa.destroy_all
        @attribute.controlled_term_taxa.create!( taxon: subfamily )
        Delayed::Worker.new.work_off
        expect( Annotation.find_by_id( @annotation.id ) ).to be_blank
      end
    end
  end

  describe "deletable_by?" do
    it "users can delete their own annotations" do
      a = make_annotation
      expect( a.deleteable_by?( a.user ) ).to be true
    end

    it "resource owners can delete annotations on their resources" do
      o = Observation.make!
      a = make_annotation( resource: o )
      expect( a.user ).not_to eq o.user
      expect( a.deleteable_by?( o.user ) ).to be true
    end
  end
end
