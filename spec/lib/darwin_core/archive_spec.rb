require "spec_helper"

describe DarwinCore::Archive, "make_metadata" do
  elastic_models( Observation )
  before do
    make_research_grade_observation
  end
  it "should include an archive license if specified" do
    license = "CC0"
    archive = DarwinCore::Archive.new( license: license )
    xml = Nokogiri::XML( File.open( archive.make_metadata ) )
    rights_elt = xml.at_xpath( "//intellectualRights" )
    expect( rights_elt.to_s ).to match /#{ FakeView.url_for_license(license) }/
  end

  it "should include a contact from the default config" do
    archive = DarwinCore::Archive.new
    xml = Nokogiri::XML( File.open( archive.make_metadata ) )
    contact_elt = xml.at_xpath( "//contact" )
    expect( contact_elt.to_s ).to match /#{ Site.default.contact[:first_name] }/
  end
end

describe DarwinCore::Archive, "make_descriptor" do
  it "should include the Simple Multimedia extension" do
    archive = DarwinCore::Archive.new( extensions: %w(SimpleMultimedia) )
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    extension_elt = xml.at_xpath('//xmlns:extension')
    expect( extension_elt['rowType'] ).to eq 'http://rs.gbif.org/terms/1.0/Multimedia'
  end
  it "should include the ObservationFields extension" do
    archive = DarwinCore::Archive.new(extensions: %w(ObservationFields))
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    extension_elt = xml.at_xpath('//xmlns:extension')
    expect( extension_elt['rowType'] ).to eq 'http://www.inaturalist.org/observation_fields'
  end
  it "should include the ProjectObservations extension" do
    archive = DarwinCore::Archive.new(extensions: %w(ProjectObservations))
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    extension_elt = xml.at_xpath('//xmlns:extension')
    expect( extension_elt['rowType'] ).to eq 'http://www.inaturalist.org/project_observations'
  end
  it "should include multiple extensions" do
    archive = DarwinCore::Archive.new(extensions: %w(ObservationFields SimpleMultimedia))
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    row_types = xml.xpath('//xmlns:extension').map{|elt| elt['rowType']}
    expect( row_types ).to include 'http://www.inaturalist.org/observation_fields'
    expect( row_types ).to include 'http://rs.gbif.org/terms/1.0/Multimedia'
  end
  it "should include additional fields for ALA if requested" do
    archive = DarwinCore::Archive.new
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    core_field_terms = xml.xpath( "//xmlns:archive/xmlns:core/xmlns:field" ).map{ |f| f["term"] }
    DarwinCore::Occurrence::ALA_EXTRA_TERMS.each do |ala_extra_term|
      expect( core_field_terms ).to_not include ala_extra_term[1]
    end

    archive = DarwinCore::Archive.new( ala: true )
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    core_field_terms = xml.xpath( "//xmlns:archive/xmlns:core/xmlns:field" ).map{ |f| f["term"] }
    DarwinCore::Occurrence::ALA_EXTRA_TERMS.each do |ala_extra_term|
      expect( core_field_terms ).to include ala_extra_term[1]
    end
  end
  it "should include additional field for otherCatalogueNumbers if requested" do
    archive = DarwinCore::Archive.new
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    core_field_terms = xml.xpath( "//xmlns:archive/xmlns:core/xmlns:field" ).map{ |f| f["term"] }
    expect( core_field_terms ).to_not include "http://rs.tdwg.org/dwc/terms/otherCatalogNumbers"

    archive = DarwinCore::Archive.new( include_uuid: true )
    xml = Nokogiri::XML( File.open( archive.make_descriptor ) )
    core_field_terms = xml.xpath( "//xmlns:archive/xmlns:core/xmlns:field" ).map{ |f| f["term"] }
    expect( core_field_terms ).to include "http://rs.tdwg.org/dwc/terms/otherCatalogNumbers"
  end
end

describe DarwinCore::Archive, "make_simple_multimedia_data" do
  elastic_models( Observation, Taxon )

  let(:o) { make_research_grade_observation }
  let(:p) { 
    photo = o.photos.first
    without_delay { photo.update(license: Photo::CC_BY) }
    DarwinCore::SimpleMultimedia.adapt(photo, observation: o)
  }

  it "should not choke if a taxon was specified" do
    archive = DarwinCore::Archive.new(taxon: o.taxon_id, extensions: %w(SimpleMultimedia))
    expect {
      archive.make_data
    }.not_to raise_exception
  end
  
  it "should set the license to a URI" do
    expect( p.license ).to eq Photo::CC_BY
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia))
    archive.make_data
    path = archive.extension_paths[:simple_multimedia]
    expect( CSV.read( path ) .size ).to be > 1
    CSV.foreach( path, headers: true ) do |row|
      expect( row['license'] ).to match /creativecommons.org/
    end
  end

  it "should set the core ID in the first column to the observation ID by default" do
    expect( p.license ).to eq Photo::CC_BY
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia))
    archive.make_data
    path = archive.extension_paths[:simple_multimedia]
    expect( CSV.read( path ).size ).to be > 1
    CSV.foreach( path, headers: true) do |row|
      expect( row['id'].to_i ).to eq o.id
    end
  end

  it "should set the core ID in the first column to the taxon ID if the core is taxon" do
    3.times { Taxon.make! }
    expect( o.id ).not_to eq o.taxon_id
    expect( p.license ).to eq Photo::CC_BY
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia), core: 'taxon')
    archive.make_data
    path = archive.extension_paths[:simple_multimedia]
    expect( CSV.read( path ).size ).to be > 1
    CSV.foreach( path, headers: true) do |row|
      expect( row['id'].to_i ).to eq o.taxon_id
    end
  end

  it "should include CC0-licensed photos by default" do
    without_delay { p.update( license: Photo::CC0 ) }
    expect( p.license ).to eq Photo::CC0
    expect( Photo.count ).to eq 1
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia))
    archive.make_data
    path = archive.extension_paths[:simple_multimedia]
    csv = CSV.read( path )
    expect( csv.size ).to eq 2 # including the header
  end

  it "should not include unlicensed photos by default" do
    expect( p.license ).not_to eq Photo::COPYRIGHT
    without_delay { p.update( license: Photo::COPYRIGHT ) }
    expect( p.license ).to eq Photo::COPYRIGHT
    expect( Photo.count ).to eq 1
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia))
    archive.make_data
    path = archive.extension_paths[:simple_multimedia]
    csv = CSV.read( path )
    expect( csv.size ).to eq 1 # just the header
  end

  describe "with photo_license is ignore" do
    it "should include CC_BY images" do
      expect( p.license ).to eq Photo::CC_BY
      archive = DarwinCore::Archive.new( extensions: %w(SimpleMultimedia), photo_licenses: ["ignore"])
      archive.make_data
      path = archive.extension_paths[:simple_multimedia]
      expect( CSV.read( path ).size ).to eq 2
    end
    it "should include unlicensed images" do
      without_delay { p.update( license: nil ) }
      expect( p.license ).to eq Photo::COPYRIGHT
      p.observations.each(&:elastic_index!)
      archive = DarwinCore::Archive.new( extensions: %w(SimpleMultimedia), photo_licenses: ["ignore"])
      archive.make_data
      path = archive.extension_paths[:simple_multimedia]
      expect( CSV.read( path ).size ).to eq 2
    end
  end
end

describe DarwinCore::Archive, "make_observation_fields_data" do
  elastic_models( Observation )

  let(:o) { make_research_grade_observation }
  let(:of) { ObservationField.make! }
  let(:ofv) {
    ofv = ObservationFieldValue.make!( observation: o )
    DarwinCore::ObservationFields.adapt( ofv, observation: o )
  }

  before do
    expect( ofv.observation ).to eq o
  end

  it "should add rows to the file" do
    archive = DarwinCore::Archive.new(extensions: %w(ObservationFields))
    archive.make_data
    path = archive.extension_paths[:observation_fields]
    expect( CSV.read( path ).size ).to be > 1
    CSV.foreach( path, headers: true ) do |row|
      expect( row['value'] ).to eq ofv.value
    end
  end

  it "should set the first column to the observation_id" do
    archive = DarwinCore::Archive.new(extensions: %w(ObservationFields))
    archive.make_data
    path = archive.extension_paths[:observation_fields]
    csv = CSV.read( path, headers: true )
    row = csv.first
    expect( row[0] ).to eq o.id.to_s
  end

  it "should only export observation field values for observations matching the params" do
    ofv1 = ObservationFieldValue.make!( observation: make_research_grade_observation )
    archive = DarwinCore::Archive.new(extensions: %w(ObservationFields), taxon: ofv1.observation.taxon )
    archive.make_data
    path = archive.extension_paths[:observation_fields]
    csv = CSV.read( path, headers: true )
    expect( csv.size ).to eq 1
  end
end

describe DarwinCore::Archive, "make_resource_relationships_data" do
  elastic_models( Observation )

  let( :o ) { make_research_grade_observation }
  let( :of_taxon ) { ObservationField.make!( datatype: "taxon" ) }
  let( :of_taxon_non_numeric ) { ObservationField.make!( datatype: "taxon" ) }
  let( :of_numeric ) { ObservationField.make!( datatype: "numeric" ) }
  let!( :ofv_taxon ) {
    ofv = ObservationFieldValue.make!( observation: o, observation_field: of_taxon, value: Taxon.make!.id )
    DarwinCore::ObservationFields.adapt( ofv, observation: o )
  }
  let!( :ofv_taxon_non_numeric_value ) {
    ofv = ObservationFieldValue.make!( observation: o, observation_field: of_taxon_non_numeric, value: "not_a_number" )
    DarwinCore::ObservationFields.adapt( ofv, observation: o )
  }
  let!( :ofv_numeric ) {
    ofv = ObservationFieldValue.make!( observation: o, observation_field: of_numeric )
    DarwinCore::ObservationFields.adapt( ofv, observation: o )
  }

  before do
    expect( ofv_taxon.observation ).to eq o
  end

  it "should add rows to the file" do
    archive = DarwinCore::Archive.new( extensions: %w( ResourceRelationships ) )
    archive.make_data
    path = archive.extension_paths[:resource_relationships]
    expect( CSV.read( path ).size ).to be > 1
    CSV.foreach( path, headers: true ) do |row|
      expect( row["identifier"] ).to eq ofv_taxon.id.to_s
      expect( row["relationshipOfResource"] ).to eq ofv_taxon.observation_field.name
      expect( row["relationshipEstablishedDate"] ).to eq ofv_taxon.created_at.iso8601
    end
  end

  it "should set the first column to the observation_id" do
    archive = DarwinCore::Archive.new( extensions: %w( ResourceRelationships ) )
    archive.make_data
    path = archive.extension_paths[:resource_relationships]
    csv = CSV.read( path, headers: true )
    row = csv.first
    expect( row[0] ).to eq o.id.to_s
  end

  it "should only export observation field values for fields of datatype taxon with numeric values" do
    archive = DarwinCore::Archive.new( extensions: %w( ResourceRelationships ) )
    archive.make_data
    path = archive.extension_paths[:resource_relationships]
    expect( CSV.read( path ).select{ |r| r[0] != "id" }.size ).to eq 1
    expect( ObservationFieldValue.count ).to be >= 3
  end
end

describe DarwinCore::Archive, "make_project_observations_data" do
  elastic_models( Observation )

  let(:o) { make_research_grade_observation }
  let(:po) {
    po = ProjectObservation.make!( observation: o )
    DarwinCore::ProjectObservations.adapt( po, observation: o )
  }

  before do
    expect( po ).to be_valid
    expect( po.observation ).to eq o
  end

  it "should add rows to the file" do
    archive = DarwinCore::Archive.new(extensions: %w(ProjectObservations))
    archive.make_data
    path = archive.extension_paths[:project_observations]
    expect( CSV.read( path ).size ).to be > 1
    CSV.foreach( path, headers: true ) do |row|
      expect( row['projectID'] ).to eq FakeView.project_url( po.project_id )
      expect( row['projectTitle'] ).to eq po.project.title
    end
  end

  it "should set the first column to the observation_id" do
    archive = DarwinCore::Archive.new(extensions: %w(ProjectObservations))
    archive.make_data
    path = archive.extension_paths[:project_observations]
    csv = CSV.read( path, headers: true )
    row = csv.first
    expect( row[0] ).to eq o.id.to_s
  end

  it "should only export observation field values for observations matching the params" do
    po1 = ProjectObservation.make!( observation: make_research_grade_observation )
    archive = DarwinCore::Archive.new(extensions: %w(ProjectObservations), taxon: po1.observation.taxon )
    archive.make_data
    path = archive.extension_paths[:project_observations]
    csv = CSV.read( path, headers: true )
    expect( csv.size ).to eq 1
  end
end

describe DarwinCore::Archive, "make_occurrence_data" do
  elastic_models( Observation, Project, Taxon )

  it "should filter by taxon" do
    parent = Taxon.make!(rank: Taxon::GENUS)
    taxon = Taxon.make!(parent: parent, rank: Taxon::SPECIES)
    expect( taxon.ancestor_ids ).to include parent.id
    in_taxon = make_research_grade_observation(taxon: taxon)
    not_in_taxon = make_research_grade_observation
    archive = DarwinCore::Archive.new(taxon: parent.id)
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include in_taxon.id
    expect( ids ).not_to include not_in_taxon.id
  end

  it "should filter by multiple taxa" do
    t1 = Taxon.make!( rank: Taxon::SPECIES )
    t2 = Taxon.make!( rank: Taxon::SPECIES )
    in_t1 = make_research_grade_observation( taxon: t1 )
    in_t2 = make_research_grade_observation( taxon: t2 )
    not_in_either_taxon = make_research_grade_observation
    archive = DarwinCore::Archive.new( taxon: "#{t1.id},#{t2.id}" )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include in_t1.id
    expect( ids ).to include in_t2.id
    expect( ids ).not_to include not_in_either_taxon.id
  end

  it "should filter by place" do
    p = make_place_with_geom
    in_place = make_research_grade_observation(latitude: p.latitude, longitude: p.longitude)
    not_in_place = make_research_grade_observation(latitude: p.latitude*-1, longitude: p.longitude*-1)
    expect( in_place.places ).to include p
    expect( not_in_place.places ).not_to include p
    archive = DarwinCore::Archive.new(place: p.id)
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include in_place.id
    expect( ids ).not_to include not_in_place.id
  end

  it "should filter by bounding box" do
    in_box = make_research_grade_observation( latitude: 0.5, longitude: 0.5 )
    not_in_box = make_research_grade_observation( latitude: 1.5, longitude: 1.5 )
    archive = DarwinCore::Archive.new(
      swlat: 0,
      swlng: 0,
      nelat: 1,
      nelng: 1
    )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include in_box.id
    expect( ids ).not_to include not_in_box.id
  end

  it "should filter by license" do
    o_cc_by = make_research_grade_observation( license: Observation::CC_BY )
    o_cc_by_nd = make_research_grade_observation( license: Observation::CC_BY_ND )
    archive = DarwinCore::Archive.new( licenses: [ Observation::CC_BY ] )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include o_cc_by.id
    expect( ids ).not_to include o_cc_by_nd.id
  end

  it "should filter by multiple licenses" do
    o_cc_by = make_research_grade_observation( license: Observation::CC_BY )
    o_cc0 = make_research_grade_observation( license: Observation::CC0 )
    o_cc_by_nd = make_research_grade_observation( license: Observation::CC_BY_ND )
    archive = DarwinCore::Archive.new( licenses: [ Observation::CC_BY, Observation::CC0 ] )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include o_cc_by.id
    expect( ids ).to include o_cc0.id
    expect( ids ).not_to include o_cc_by_nd.id
  end

  it "should include unlicensed observations when licenses is ignore" do
    o = make_research_grade_observation
    without_delay { o.update( license: nil ) }
    expect( o.license ).to be_blank
    archive = DarwinCore::Archive.new( licenses: [ "ignore" ] )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include o.id
  end

  it "should filter by project" do
    in_project = make_research_grade_observation
    po_in_project = ProjectObservation.make!( observation: in_project )
    not_in_project = make_research_grade_observation
    po_not_in_project = ProjectObservation.make!( observation: not_in_project )
    expect( po_in_project.project ).not_to eq po_not_in_project.project
    expect( po_in_project.project.observations ).not_to include not_in_project
    archive = DarwinCore::Archive.new( project: po_in_project.project )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include in_project.id
    expect( ids ).not_to include not_in_project.id
  end

  it "should filter by d1" do
    outside_o = make_research_grade_observation( observed_on_string: 20.years.ago.to_s )
    inside_o = make_research_grade_observation( observed_on_string: 2.years.ago.to_s )
    archive = DarwinCore::Archive.new( d1: 10.years.ago.to_date.to_s )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map {| r | r[0].to_i }
    expect( ids ).to include inside_o.id
    expect( ids ).not_to include outside_o.id
  end

  it "should filter by d2" do
    inside_o = make_research_grade_observation( observed_on_string: 20.years.ago.to_s )
    outside_o = make_research_grade_observation( observed_on_string: 2.years.ago.to_s )
    archive = DarwinCore::Archive.new( d2: 10.years.ago.to_date.to_s )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map {| r | r[0].to_i }
    expect( ids ).to include inside_o.id
    expect( ids ).not_to include outside_o.id
  end

  it "should set the license to a URI" do
    o_cc_by = make_research_grade_observation( license: Observation::CC_BY )
    archive = DarwinCore::Archive.new( licenses: [ Observation::CC_BY, Observation::CC0 ] )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    CSV.foreach( path, headers: true ) do |row|
      expect( row['license'] ).to match URI::URI_REF
    end
  end

  it "should set CC license URI using the current version" do
    o_cc_by = make_research_grade_observation( license: Observation::CC_BY )
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    CSV.foreach( path, headers: true ) do |row|
      expect( row['license'] ).to match /\/#{ Shared::LicenseModule::CC_VERSION }\//
    end
  end

  it "should set CC0 license URI using the current version" do
    o_cc0 = make_research_grade_observation( license: Observation::CC0 )
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    CSV.foreach( path, headers: true ) do |row|
      expect( row['license'] ).to match /\/#{ Shared::LicenseModule::CC0_VERSION }\//
    end
  end

  it "should only include research grade observations by default" do
    rg = make_research_grade_observation
    ni = make_research_grade_candidate_observation
    ca = Observation.make!
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( rg.license ).not_to be_blank
    expect( ni.license ).not_to be_blank
    expect( ca.license ).not_to be_blank
    expect( ids ).to include rg.id
    expect( ids ).not_to include ni.id
    expect( ids ).not_to include ca.id
  end

  it "should only include licensed observations by default" do
    with_license = make_research_grade_observation(license: Observation::CC_BY)
    without_license = make_research_grade_observation(license: nil)
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids ).to include with_license.id
    expect( ids ).not_to include without_license.id
  end

  it "should not include duplicates" do
    number_of_obs = 5
    number_of_obs.times { Observation.make! }
    archive = DarwinCore::Archive.new(quality: "any")
    archive.make_data
    path = archive.extension_paths[:occurrence]
    ids = CSV.read( path, headers: true ).map{|r| r[0].to_i}
    expect( ids.size ).to eq number_of_obs
    expect( ids.uniq.size ).to eq ids.size
  end

  it "should not include private coordinates by default" do
    o = make_research_grade_observation(geoprivacy: Observation::PRIVATE)
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    obs = CSV.read( path, headers: true ).first
    expect( obs['id'] ).to eq o.id.to_s
    expect( obs['decimalLatitude'] ).not_to eq o.private_latitude.to_s
    expect( obs['decimalLongitude'] ).not_to eq o.private_longitude.to_s
  end

  it "should include uuids if requested" do
    o = make_research_grade_observation
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    obs = CSV.read( path, headers: true ).first
    expect( obs.key?("otherCatalogueNumbers") ).to be false

    archive = DarwinCore::Archive.new( include_uuid: true )
    archive.make_data
    path = archive.extension_paths[:occurrence]
    obs = CSV.read( path, headers: true ).first
    expect( obs.key?("otherCatalogueNumbers") ).to be true
    expect( obs["otherCatalogueNumbers"] ).to eq o.uuid
  end

  it "should report coordinateUncertaintyInMeters as the longest diagonal across the uncertainty cell" do
    o = make_research_grade_observation(geoprivacy: Observation::OBSCURED)
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    obs = CSV.read( path, headers: true ).first
    expect( obs['coordinateUncertaintyInMeters'] ).to eq o.uncertainty_cell_diagonal_meters.to_s
  end

  describe "annotation filters" do
    before( :all ) do
      @sex_attribute = make_controlled_term_with_label( "Sex" )
      @life_stage_attribute = make_controlled_term_with_label( "Life Stage" )
      @unrecognized_attribute = make_controlled_term_with_label( "Unrecognized" )
      @sex_value = make_controlled_value_with_label( "Sex value", @sex_attribute )
      @larva = make_controlled_value_with_label( "Larva", @life_stage_attribute )
      @teneral = make_controlled_value_with_label( "Teneral", @life_stage_attribute )
      @unrecognized_attribute_value = make_controlled_value_with_label(
        "Unrecognized value", @unrecognized_attribute
      )
      @unannotated_o = make_research_grade_observation
      @sex_annotated_o = make_research_grade_observation
      Annotation.make!(
        resource: @sex_annotated_o,
        controlled_attribute: @sex_attribute,
        controlled_value: @sex_value
      )
      @larva_annotated_o = make_research_grade_observation
      Annotation.make!(
        resource: @larva_annotated_o,
        controlled_attribute: @life_stage_attribute,
        controlled_value: @larva
      )
      @teneral_annotated_o = make_research_grade_observation
      Annotation.make!(
        resource: @teneral_annotated_o,
        controlled_attribute: @life_stage_attribute,
        controlled_value: @teneral
      )
      @unrecognized_annotated_o = make_research_grade_observation
      Annotation.make!(
        resource: @unrecognized_annotated_o,
        controlled_attribute: @unrecognized_attribute,
        controlled_value: @unrecognized_attribute_value
      )
    end
    before( :each ) { Observation.elastic_index! }

    it "should filter by annotation presence" do
      archive = DarwinCore::Archive.new( with_annotations: true )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      ids = CSV.read( path, headers: true ).map {| r | r[0].to_i }
      expect( ids ).to include @sex_annotated_o.id
      expect( ids ).to include @larva_annotated_o.id
      expect( ids ).to include @teneral_annotated_o.id
      expect( ids ).not_to include @unannotated_o.id
      expect( ids ).not_to include @unrecognized_annotated_o.id
    end

    it "should filter by annotations of a particular term" do
      archive = DarwinCore::Archive.new( with_controlled_terms: ["Sex"] )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      ids = CSV.read( path, headers: true ).map {| r | r[0].to_i }
      expect( ids ).to include @sex_annotated_o.id
      expect( ids ).to_not include @larva_annotated_o.id
      expect( ids ).to_not include @teneral_annotated_o.id
      expect( ids ).not_to include @unannotated_o.id
      expect( ids ).not_to include @unrecognized_annotated_o.id
    end

    it "should filter by annotations of mulitple terms" do
      archive = DarwinCore::Archive.new( with_controlled_terms: ["Sex", "Life Stage"] )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      ids = CSV.read( path, headers: true ).map {| r | r[0].to_i }
      expect( ids ).to include @sex_annotated_o.id
      expect( ids ).to include @larva_annotated_o.id
      expect( ids ).to include @teneral_annotated_o.id
      expect( ids ).not_to include @unannotated_o.id
      expect( ids ).not_to include @unrecognized_annotated_o.id
    end

    it "should filter by annotations of a term and value" do
      archive = DarwinCore::Archive.new(
        with_controlled_terms: ["Life Stage"],
        with_controlled_values: ["Larva"]
      )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      ids = CSV.read( path, headers: true ).map {| r | r[0].to_i }
      expect( ids ).to_not include @sex_annotated_o.id
      expect( ids ).to include @larva_annotated_o.id
      expect( ids ).to_not include @teneral_annotated_o.id
      expect( ids ).not_to include @unannotated_o.id
      expect( ids ).not_to include @unrecognized_annotated_o.id
    end

    it "should filter by annotations of a term and multiple values" do
      archive = DarwinCore::Archive.new(
        with_controlled_terms: ["Life Stage"],
        with_controlled_values: ["Larva", "Teneral"]
      )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      ids = CSV.read( path, headers: true ).map {| r | r[0].to_i }
      expect( ids ).to_not include @sex_annotated_o.id
      expect( ids ).to include @larva_annotated_o.id
      expect( ids ).to include @teneral_annotated_o.id
      expect( ids ).not_to include @unannotated_o.id
      expect( ids ).not_to include @unrecognized_annotated_o.id
    end
  end

  describe "private_coordinates" do
    it "should include private coordinates" do
      o = make_research_grade_observation(geoprivacy: Observation::PRIVATE)
      archive = DarwinCore::Archive.new(private_coordinates: true)
      archive.make_data
      path = archive.extension_paths[:occurrence]
      obs = CSV.read( path, headers: true ).first
      expect( obs['id'] ).to eq o.id.to_s
      expect( obs['decimalLatitude'] ).to eq o.private_latitude.to_s
      expect( obs['decimalLongitude'] ).to eq o.private_longitude.to_s
      expect( obs["informationWithheld"] ).to be_blank
    end

    it "should report coordinateUncertaintyInMeters as the positional_accuracy" do
      o = make_research_grade_observation( geoprivacy: Observation::OBSCURED, positional_accuracy: 10 )
      archive = DarwinCore::Archive.new(private_coordinates: true)
      archive.make_data
      path = archive.extension_paths[:occurrence]
      obs = CSV.read( path, headers: true ).first
      expect( obs['coordinateUncertaintyInMeters'] ).to eq o.positional_accuracy.to_s
    end

    it "should report coordinateUncertaintyInMeters as blank if positional_accuracy is blank" do
      o = make_research_grade_observation(geoprivacy: Observation::OBSCURED)
      archive = DarwinCore::Archive.new(private_coordinates: true)
      archive.make_data
      path = archive.extension_paths[:occurrence]
      obs = CSV.read( path, headers: true ).first
      expect( obs['coordinateUncertaintyInMeters'] ).to be_blank
    end
  end

  describe "taxon_private_coordinates" do
    let(:threatened_taxon) {
      t = Taxon.make!( rank: Taxon::SPECIES )
      ct = ConservationStatus.make!( taxon: t )
      t
    }
    it "should include private coordinates for an observation of a threatened taxon" do
      o = make_research_grade_observation( taxon: threatened_taxon )
      expect( o ).to be_coordinates_obscured
      archive = DarwinCore::Archive.new( taxon_private_coordinates: true )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      obs = CSV.read( path, headers: true, ).first
      expect( obs["id"] ).to eq o.id.to_s
      expect( obs["decimalLatitude"] ).to eq o.private_latitude.to_s
      expect( obs["decimalLongitude"] ).to eq o.private_longitude.to_s
      expect( obs["informationWithheld"] ).to be_blank
    end
    it "should not include private coordinates for an observation of a threatened taxon with obscured geoprivacy" do
      o = make_research_grade_observation(
        taxon: threatened_taxon,
        geoprivacy: Observation::OBSCURED
      )
      expect( o ).to be_coordinates_obscured
      archive = DarwinCore::Archive.new( taxon_private_coordinates: true )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      obs = CSV.read( path, headers: true ).first
      expect( obs["id"] ).to eq o.id.to_s
      expect( obs["decimalLatitude"] ).not_to eq o.private_latitude.to_s
      expect( obs["decimalLongitude"] ).not_to eq o.private_longitude.to_s
      expect( obs["informationWithheld"] ).not_to be_blank
    end
    it "should not include private coordinates for an observation of a unthreatened taxon with obscured geoprivacy" do
      o = make_research_grade_observation( geoprivacy: Observation::OBSCURED )
      expect( o ).to be_coordinates_obscured
      archive = DarwinCore::Archive.new( taxon_private_coordinates: true )
      archive.make_data
      path = archive.extension_paths[:occurrence]
      obs = CSV.read( path, headers: true ).first
      expect( obs["id"] ).to eq o.id.to_s
      expect( obs["decimalLatitude"] ).not_to eq o.private_latitude.to_s
      expect( obs["decimalLongitude"] ).not_to eq o.private_longitude.to_s
    end
  end

  it "should filter by site_id" do
    site = Site.make!
    in_site = make_research_grade_observation(site: site)
    not_in_site = make_research_grade_observation
    archive = DarwinCore::Archive.new(site_id: site.id)
    archive.make_data
    path = archive.extension_paths[:occurrence]
    obs = CSV.read( path, headers: true )
    expect( obs.detect{|o| o['id'] == in_site.id.to_s} ).not_to be_nil
    expect( obs.detect{|o| o['id'] == not_in_site.id.to_s} ).to be_nil
  end

  it "should include countryCode" do
    country = make_place_with_geom( code: "US", admin_level: Place::COUNTRY_LEVEL )
    o = without_delay do
      make_research_grade_observation( latitude: country.latitude, longitude: country.longitude )
    end
    expect( o.observations_places.map(&:place) ).to include country
    archive = DarwinCore::Archive.new
    archive.make_data
    path = archive.extension_paths[:occurrence]
    CSV.foreach( path, headers: true ) do |row|
      expect( row['countryCode'] ).to eq country.code
    end
  end
end
