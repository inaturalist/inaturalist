require File.dirname(__FILE__) + '/../spec_helper.rb'
Paperclip::Storage::Filesystem.stubbed_for_tests = false

describe TaxonRange, "derive_missing_values" do
  it "should do nothing with blank range and geometry" do
    tr = TaxonRange.new
    expect(tr).not_to receive(:create_kml_attachment)
    expect(tr).not_to receive(:create_geom_from_kml_attachment)
    tr.run_callbacks :save
  end
  
  it "should derive KML when only geometry is present" do
    tr = TaxonRange.new(geom: true)
    expect(tr).to receive(:create_kml_attachment)
    expect(tr).not_to receive(:create_geom_from_kml_attachment)
    tr.run_callbacks :save
  end
  
  it "should derive geom when only KML is present" do
    tr = TaxonRange.new(range: Tempfile.new(['temp', '.kml']))
    expect(tr).not_to receive(:create_kml_attachment)
    expect(tr).to receive(:create_geom_from_kml_attachment)
    tr.run_callbacks :save
  end
end

describe TaxonRange, "create_kml_attachment" do
  it "should create an kml attachment from geometry" do
    tr = make_taxon_range_with_geom
    expect(tr.range).not_to be_blank
    kml = open(tr.range.path).read
    expect(kml).to be =~ /<kml /
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
    expect(tr.geom).not_to be_blank
    expect(TaxonRange.where("ST_Contains(geom, ST_Point(0.5,0.5)) AND id = ?", tr)).not_to be_blank
  end
end
