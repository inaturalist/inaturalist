# frozen_string_literal: true

require "spec_helper"

Paperclip::Storage::Filesystem.stubbed_for_tests = false

describe TaxonRange do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :source }
  it { is_expected.to have_many( :listed_taxa ).dependent :nullify }
end

describe TaxonRange do
  describe "create_kml_attachment" do
    it "should create an kml attachment from geometry" do
      tr = without_delay { make_taxon_range_with_geom }
      expect( tr.range ).not_to be_blank
      kml = File.read( tr.range.path )
      expect( kml ).to be =~ /<kml /
    end
  end

  describe "create_geom_from_kml_attachment" do
    it "should create a geom from a kml attachment" do
      kml = <<~XML
        <?xml version="1.0"?>
        <kml xmlns="http://earth.google.com/kml/2.1">
          <Document>
            <Placemark>
              <name/>
              <description/>
              <MultiGeometry>
                <Polygon>
                  <outerBoundaryIs>
                    <LinearRing>
                      <coordinates>
                        0.0,0.0 0.0,1.0 1.0,1.0 1.0,0.0 0.0,0.0
                      </coordinates>
                    </LinearRing>
                  </outerBoundaryIs>
                </Polygon>
              </MultiGeometry>
            </Placemark>
          </Document>
        </kml>
      XML
      f = Tempfile.new( ["test", ".kml"] )
      f.write( kml )
      f.rewind
      tr = without_delay { TaxonRange.make!( range: f ) }
      expect( tr.geom ).not_to be_blank
      expect( TaxonRange.where( "ST_Contains(geom, ST_Point(0.5,0.5)) AND id = ?", tr ) ).not_to be_blank
    end
  end

  describe "validate_geometry" do
    it "should be valid with valid geom" do
      taxon_range = TaxonRange.make!
      taxon_range.geom = <<-WKT
        MULTIPOLYGON(
          (
            (
              -122.247619628906 37.8547693305679,
              -122.284870147705 37.8490764953623,
              -122.299289703369 37.8909492165781,
              -122.250881195068 37.8970452004104,
              -122.239551544189 37.8719807055375,
              -122.247619628906 37.8547693305679
            )
          )
        )
      WKT
      expect( taxon_range ).to be_valid
    end

    it "should be invalid with a three-point polygon" do
      taxon_range = TaxonRange.make!
      two_pt_polygon = "MULTIPOLYGON(((-122.24 37.85,-122.28 37.84,-122.28 37.83)))"
      taxon_range.geom = two_pt_polygon
      expect( taxon_range ).not_to be_valid
    end

    it "should be invalid with a latitude greater than 90" do
      taxon_range = TaxonRange.make!
      impossible_polygon = "MULTIPOLYGON(((0 89,0 91,1 91,0 91,0 89)))"
      taxon_range.geom = impossible_polygon
      expect( taxon_range ).not_to be_valid
      expect( taxon_range.errors.size ).to eq 1
    end

    it "should be invalid with a longitude greater than 180" do
      taxon_range = TaxonRange.make!
      impossible_polygon = "MULTIPOLYGON(((180 89,181 89,180 89,180 89,180 89)))"
      taxon_range.geom = impossible_polygon
      expect( taxon_range ).not_to be_valid
      expect( taxon_range.errors.size ).to eq 1
    end

    it "should be invalid with a polygon that has 4 identical points" do
      taxon_range = TaxonRange.make!
      impossible_polygon = "MULTIPOLYGON(((1 1,1 1,1 1,1 1)))"
      taxon_range.geom = impossible_polygon
      expect( taxon_range ).not_to be_valid
      expect( taxon_range.errors.size ).to eq 1
    end
  end
end
