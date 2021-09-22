require File.dirname( __FILE__ ) + "/../spec_helper.rb"

describe ExifMetadata, "extract" do
  let( :missing_file ) { "./non-existent-file.jpg" }
  let( :jpg_exif ) { "spec/fixtures/files/cuthona_abronia-tagged.jpg" }
  let( :png_exif ) { "spec/fixtures/files/cuthona_abronia-tagged.png" }
  let( :png_ztxt ) { "spec/fixtures/files/polistes_dominula-png-metadata.png" }
  
  it "should handle file exceptions" do
    expect( ExifMetadata.new( path: nil, type: nil ).extract).to eq( {} )
    expect( ExifMetadata.new( path: missing_file, type: nil ).extract).to eq( {} )
    expect{ ExifMetadata.new( path: missing_file, type: "jpg" ).extract }.to raise_error ExifMetadata::ExtractionError
  end

  context "JPEG" do
    context "exif metadata" do
      it "should handle malformed images" do
        expect{ ExifMetadata.new( path: png_exif, type: "jpg" ).extract }.to raise_error EXIFR::MalformedImage
      end
      
      it "should return metadata" do
        md = ExifMetadata.new( path: jpg_exif, type: "jpg" ).extract
        exif = EXIFR::JPEG.new( jpg_exif ).to_hash
        
        expect( md[:gps_latitude] ).to eq exif[:gps_latitude]
        expect( md[:gps_longitude] ).to eq exif[:gps_longitude]
        expect( md[:date_time_original] ).to eq exif[:date_time_original]
      end  
    end
  end
  
  context "PNG" do
    context "tEXt/zTXt metadata" do
      it "should return metadata" do
        md = ExifMetadata.new( path: png_ztxt, type: "png" ).extract
        exif = Exiftool.new( png_ztxt ).to_hash
        
        expect( md[:image_description] ).to eq exif[:description]
        expect( md[:user_comment] ).to eq exif[:comment]
        expect( md[:copyright] ).to eq exif[:copyright]
        expect( md[:software] ).to eq exif[:software]
      end
    end
    
    context "exif metadata" do
      it "should return metadata" do
        md = ExifMetadata.new( path: png_exif, type: "png" ).extract
        exif = Exiftool.new( png_exif ).to_hash

        expect( md[:gps_latitude] ).to eq exif[:gps_latitude]
        expect( md[:gps_longitude] ).to eq exif[:gps_longitude]
        expect( md[:date_time_original] ).to eq( Time.strptime( exif[:date_time_original], "%Y:%m:%d %H:%M:%S" ) )
      end
      
      it "should trim tags not included by EXIFR" do
        md = ExifMetadata.new( path: png_exif, type: "png" ).extract
        expect( ( md.keys & EXIFR::TIFF::TAGS ).count).to eq md.keys.count
      end
      
      it "should cast date times to objects" do
        md = ExifMetadata.new( path: png_exif, type: "png" ).extract
        %i[date_time_digitized date_time_original modify_date].each do |dt| 
          expect( md[dt]).to be_a( Time ) if md[dt].present?
        end
      end
    end
  end
  
  context "Dublin Core" do
    it "should extract Dublin Core tags from XMP" do
      md = ExifMetadata.new( path: jpg_exif, type: "jpg" ).extract
      dc = XMP.parse( EXIFR::JPEG.new( jpg_exif ) ).dc
      
      dc.attributes.each { |attr| expect( md[:dc][attr.to_sym] ).to eq dc.send( attr ) }
    end
  end
end
