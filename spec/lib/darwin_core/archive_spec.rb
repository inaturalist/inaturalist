require "spec_helper"

describe DarwinCore::Archive, "make_descriptor" do
  it "should include the Simple Multimedia extension" do
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia))
    xml = Nokogiri::XML(open(archive.make_descriptor))
    extension_elt = xml.at_xpath('//xmlns:extension')
    expect( extension_elt['rowType'] ).to eq 'http://rs.gbif.org/terms/1.0/Multimedia'
  end
end

describe DarwinCore::Archive, "make_simple_multimedia_data" do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }

  let(:o) { make_research_grade_observation }
  let(:p) { 
    photo = o.photos.first
    without_delay { photo.update_attributes(license: Photo::CC_BY) }
    DarwinCore::SimpleMultimedia.adapt(photo, observation: o)
  }

  it "should not choke if a taxon was specified" do
    archive = DarwinCore::Archive.new(taxon: o.taxon_id, extensions: %w(SimpleMultimedia))
    expect {
      archive.make_simple_multimedia_data
    }.not_to raise_exception
  end
  
  it "should set the license to a URI" do
    expect( p.license ).to eq Photo::CC_BY
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia))
    expect( CSV.read(archive.make_simple_multimedia_data).size ).to be > 1
    CSV.foreach(archive.make_simple_multimedia_data, headers: true) do |row|
      expect( row['license'] ).to match /creativecommons.org/
    end
  end

  it "should set the core ID in the first column to the observation ID by default" do
    expect( p.license ).to eq Photo::CC_BY
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia))
    expect( CSV.read(archive.make_simple_multimedia_data).size ).to be > 1
    CSV.foreach(archive.make_simple_multimedia_data, headers: true) do |row|
      expect( row['id'].to_i ).to eq o.id
    end
  end

  it "should set the core ID in the first column to the taxon ID if the core is taxon" do
    3.times { Taxon.make! }
    expect( o.id ).not_to eq o.taxon_id
    expect( p.license ).to eq Photo::CC_BY
    archive = DarwinCore::Archive.new(extensions: %w(SimpleMultimedia), core: 'taxon')
    expect( CSV.read(archive.make_simple_multimedia_data).size ).to be > 1
    CSV.foreach(archive.make_simple_multimedia_data, headers: true) do |row|
      expect( row['id'].to_i ).to eq o.taxon_id
    end
  end
end

describe DarwinCore::Archive, "make_occurrence_data" do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }

  it "should filter by taxon" do
    parent = Taxon.make!(rank: Taxon::GENUS)
    taxon = Taxon.make!(parent: parent, rank: Taxon::SPECIES)
    expect( taxon.ancestor_ids ).to include parent.id
    in_taxon = make_research_grade_observation(taxon: taxon)
    not_in_taxon = make_research_grade_observation
    archive = DarwinCore::Archive.new(taxon: parent.id)
    ids = CSV.read(archive.make_occurrence_data, headers: true).map{|r| r[0].to_i}
    expect( ids ).to include in_taxon.id
    expect( ids ).not_to include not_in_taxon.id
  end

  it "should filter by place" do
    p = make_place_with_geom
    in_place = make_research_grade_observation(latitude: p.latitude, longitude: p.longitude)
    not_in_place = make_research_grade_observation(latitude: p.latitude*-1, longitude: p.longitude*-1)
    expect( in_place.places ).to include p
    expect( not_in_place.places ).not_to include p
    archive = DarwinCore::Archive.new(place: p.id)
    ids = CSV.read(archive.make_occurrence_data, headers: true).map{|r| r[0].to_i}
    expect( ids ).to include in_place.id
    expect( ids ).not_to include not_in_place.id
  end

  it "should only include research grade observations by default" do
    rg = make_research_grade_observation
    ni = make_research_grade_candidate_observation
    ca = Observation.make!
    archive = DarwinCore::Archive.new
    ids = CSV.read(archive.make_occurrence_data, headers: true).map{|r| r[0].to_i}
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
    ids = CSV.read(archive.make_occurrence_data, headers: true).map{|r| r[0].to_i}
    expect( ids ).to include with_license.id
    expect( ids ).not_to include without_license.id
  end

  it "should not include duplicates" do
    10.times { make_research_grade_observation }
    archive = DarwinCore::Archive.new
    ids = CSV.read(archive.make_occurrence_data, headers: true).map{|r| r[0].to_i}
    expect( ids.uniq.size ).to eq ids.size
  end
end
