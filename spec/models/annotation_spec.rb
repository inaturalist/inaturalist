require "spec_helper.rb"

describe Annotation do
  before(:each) { enable_elastic_indexing( ControlledTerm ) }
  after(:each) { disable_elastic_indexing( ControlledTerm ) }

  it "validates presence of resource" do
    expect{ Annotation.make!(resource: nil) }.to raise_error(
      ActiveRecord::RecordInvalid, /Resource can't be blank/)
  end

  it "validates existence of resource" do
    expect{
      Annotation.make!(resource: nil, resource_type: "Observation", resource_id: 9999)
    }.to raise_error(ActiveRecord::RecordInvalid, /Resource can't be blank/)
  end

  it "validates presence of controlled_attribute_id" do
    expect{ Annotation.make!(controlled_attribute: nil) }.to raise_error(
      ActiveRecord::RecordInvalid, /Controlled attribute can't be blank/)
  end

  it "validates attribute is an attribute" do
    atr = ControlledTerm.make!(is_value: true)
    expect{ Annotation.make!(controlled_attribute: atr) }.to raise_error(
      ActiveRecord::RecordInvalid, /Controlled attribute must be an attribute/)
  end

  it "validates value is a value" do
    val = ControlledTerm.make!
    expect{ Annotation.make!(controlled_value: val) }.to raise_error(
      ActiveRecord::RecordInvalid, /Controlled value must be a value/)
  end

  it "validates attribute belongs to value" do
    expect{
      Annotation.make!(
        controlled_attribute: ControlledTerm.make!,
        controlled_value: ControlledTerm.make!(is_value: true)
      )
    }.to raise_error(ActiveRecord::RecordInvalid, /Controlled value must belong to attribute/)
  end

  it "validates attribute belongs to taxon" do
    animalia = Taxon.make!(name: "Animalia")
    mammalia = Taxon.make!(name: "Mammalia", parent: animalia)
    AncestryDenormalizer.denormalize
    obs = Observation.make!(taxon: animalia)
    atr = ControlledTermTaxon.make!( taxon: mammalia ).controlled_term
    ctv = ControlledTermValue.make!(controlled_attribute: atr)
    expect{
      Annotation.make!(
        resource: obs,
        controlled_attribute: atr,
        controlled_value: atr.values.first
      )
    }.to raise_error(ActiveRecord::RecordInvalid, /Controlled attribute must belong to taxon/)
  end

  it "validates value belongs to taxon" do
    animalia = Taxon.make!(name: "Animalia")
    mammalia = Taxon.make!(name: "Mammalia", parent: animalia)
    AncestryDenormalizer.denormalize
    obs = Observation.make!(taxon: animalia)
    atr = ControlledTerm.make!
    val = ControlledTerm.make!( is_value: true )
    ControlledTermTaxon.make!( taxon: mammalia, controlled_term: val )
    ctv = ControlledTermValue.make!(controlled_attribute: atr, controlled_value: val)
    expect{
      Annotation.make!(
        resource: obs,
        controlled_attribute: atr,
        controlled_value: val
      )
    }.to raise_error(ActiveRecord::RecordInvalid, /Controlled value must belong to taxon/)
  end

  it "validates uniqueness of controlled_value within resource and attribute" do
    atr = ControlledTerm.make!
    val = ControlledTerm.make!(is_value: true)
    atr.controlled_term_values.create(controlled_value: val)
    original = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val
    )
    expect{
      Annotation.make!(
        resource: original.resource,
        controlled_attribute: atr,
        controlled_value: val
      )
    }.to raise_error(ActiveRecord::RecordInvalid, /Controlled value has already been taken/)
  end

  it "validates against presence of another annotation of a blocking value" do
    obs = Observation.make!
    atr = ControlledTerm.make!( multivalued: true )
    val = ControlledTerm.make!( is_value: true )
    atr.controlled_term_values.create( controlled_value: val )
    blocking_val = ControlledTerm.make!( is_value: true, blocking: true )
    atr.controlled_term_values.create( controlled_value: blocking_val )
    blocking_annotation = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: blocking_val,
      resource: obs
    )
    expect {
      Annotation.make!(
        controlled_attribute: atr,
        controlled_value: val,
        resource: obs
      )
    }.to raise_error( ActiveRecord::RecordInvalid, /blocked by another value/ )
  end

  it "validates against presence of another annotation if this is a blocking value" do
    obs = Observation.make!
    atr = ControlledTerm.make!( multivalued: true )
    val = ControlledTerm.make!( is_value: true )
    atr.controlled_term_values.create( controlled_value: val )
    blocking_val = ControlledTerm.make!( is_value: true, blocking: true )
    atr.controlled_term_values.create( controlled_value: blocking_val )
    Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val,
      resource: obs
    )
    expect {
      Annotation.make!(
        controlled_attribute: atr,
        controlled_value: blocking_val,
        resource: obs
      )
    }.to raise_error( ActiveRecord::RecordInvalid, /is blocking but another annotation already added/ )
  end

  it "creates valid instances" do
    atr = ControlledTerm.make!
    val = ControlledTerm.make!(is_value: true)
    atr.controlled_term_values.create(controlled_value: val)
    # ctv = ControlledTermValue.make!(controlled_attribute: atr, controlled_value: val)
    expect{
      Annotation.make!(
        controlled_attribute: atr,
        controlled_value: val
      )
    }.to_not raise_error
    expect(Annotation.count).to eq 1
  end

  it "does not allow multiple values per attribute unless specified" do
    atr = ControlledTerm.make!(multivalued: false)
    val1 = ControlledTerm.make!(is_value: true)
    val2 = ControlledTerm.make!(is_value: true)
    atr.controlled_term_values.create(controlled_value: val1)
    atr.controlled_term_values.create(controlled_value: val2)
    original = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val1
    )
    expect{
      Annotation.make!(
        resource: original.resource,
        controlled_attribute: atr,
        controlled_value: val2
      )
    }.to raise_error(ActiveRecord::RecordInvalid, /Controlled attribute cannot have multiple values/)
  end

  it "does allow multiple values per attribute if specified" do
    atr = ControlledTerm.make!(multivalued: true)
    val1 = ControlledTerm.make!(is_value: true)
    val2 = ControlledTerm.make!(is_value: true)
    atr.controlled_term_values.create(controlled_value: val1)
    atr.controlled_term_values.create(controlled_value: val2)
    original = Annotation.make!(
      controlled_attribute: atr,
      controlled_value: val1
    )
    expect{
      Annotation.make!(
        resource: original.resource,
        controlled_attribute: atr,
        controlled_value: val2
      )
    }.to_not raise_error
  end

end
