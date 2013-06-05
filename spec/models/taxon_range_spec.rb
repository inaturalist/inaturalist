require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonRange, "create_kml_attachment" do
  it "should create an kml attachment from geometry" do
    tr = make_taxon_range_with_geom
    tr.range.should be_blank
    tr.create_kml_attachment
    tr.range.should_not be_blank
    kml = open(tr.range.path).read
    kml.should =~ /<kml /
  end
end

describe TaxonRange, "create_geom_from_kml_attachment" do
  it "should create a geom from a kml attachment" do
    kml = <<-XML
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
    f = Tempfile.new(['test', '.kml'])
    f.write(kml)
    f.rewind
    tr = TaxonRange.make!(:range => f)
    tr.range.should_not be_blank
    tr.geom.should be_blank
    tr.create_geom_from_kml_attachment
    tr.geom.should_not be_blank
    TaxonRange.where("ST_Contains(geom, ST_Point(0.5,0.5)) AND id = ?", tr).should_not be_blank
  end
end
