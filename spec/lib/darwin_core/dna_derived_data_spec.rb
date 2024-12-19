# frozen_string_literal: true

require "spec_helper"

describe DarwinCore::DnaDerivedData do
  elastic_models( Observation, Taxon )
  let( :o ) { make_research_grade_observation }
  let( :of ) { create( :observation_field, datatype: ObservationField::DNA ) }
  let( :sequence ) { "ACTG" }
  let( :seq_meth_of ) do
    create(
      :observation_field,
      name: DarwinCore::DnaDerivedData::SEQUENCING_TECHNOLOGY_FIELD_NAME
    )
  end
  let( :seq_meth_ofv ) do
    create(
      :observation_field_value,
      observation: o,
      observation_field: seq_meth_of
    )
  end

  it "should upcase the sequence" do
    sequence_lc = "actg"
    ofv = build( :observation_field_value, observation_field: of, value: sequence_lc )
    expect( DarwinCore::DnaDerivedData.adapt( ofv ).dna_sequence ).to eq sequence_lc.upcase
  end

  it "should set target_gene to ITS for a field named DNA Barcode ITS" do
    its_of = build( :observation_field, datatype: ObservationField::DNA, name: "DNA Barcode ITS" )
    ofv = build( :observation_field_value, observation_field: its_of, value: sequence )
    expect( DarwinCore::DnaDerivedData.adapt( ofv ).target_gene ).to eq DarwinCore::DnaDerivedData::ITS
  end

  it "should set target_gene to COI for a field named DNA Barcode COI" do
    its_of = build( :observation_field, datatype: ObservationField::DNA, name: "DNA Barcode COI" )
    ofv = build( :observation_field_value, observation_field: its_of, value: sequence )
    expect( DarwinCore::DnaDerivedData.adapt( ofv ).target_gene ).to eq DarwinCore::DnaDerivedData::COI
  end

  it "should set target_gene to HSP90 for a field named DNA Barcode hsp90" do
    its_of = build( :observation_field, datatype: ObservationField::DNA, name: "DNA Barcode hsp90" )
    ofv = build( :observation_field_value, observation_field: its_of, value: sequence )
    expect( DarwinCore::DnaDerivedData.adapt( ofv ).target_gene ).to eq DarwinCore::DnaDerivedData::HSP90
  end

  it "should set seq_meth if the observation has only one DNA field" do
    expect( seq_meth_ofv ).not_to be_blank
    ofv = create(
      :observation_field_value,
      observation: o,
      observation_field: of,
      value: sequence
    )
    o.reload
    expect(
      o.observation_field_values.select do | o_ofv |
        o_ofv.observation_field.datatype == ObservationField::DNA
      end.size
    ).to eq 1
    expect( DarwinCore::DnaDerivedData.adapt( ofv ).seq_meth ).to eq seq_meth_ofv.value
  end

  it "should not set seq_meth if the observation has more than one DNA field" do
    expect( seq_meth_ofv ).not_to be_blank
    ofv1 = create(
      :observation_field_value,
      observation: o,
      observation_field: of,
      value: sequence
    )
    of2 = create( :observation_field, datatype: ObservationField::DNA )
    ofv2 = create(
      :observation_field_value,
      observation: o,
      observation_field: of2,
      value: sequence
    )
    o.reload
    expect(
      o.observation_field_values.select do | o_ofv |
        o_ofv.observation_field.datatype == ObservationField::DNA
      end.size
    ).to eq 2
    expect( DarwinCore::DnaDerivedData.adapt( ofv1 ).seq_meth ).to be_blank
    expect( DarwinCore::DnaDerivedData.adapt( ofv2 ).seq_meth ).to be_blank
  end
end
