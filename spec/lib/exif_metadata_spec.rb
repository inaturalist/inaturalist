# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

describe ExifMetadata, "extract" do
  subject { exif_metadata.extract }

  let( :path ) { "spec/fixtures/files/cuthona_abronia-tagged.jpg" }
  let( :type ) { "jpg" }
  let( :exif_metadata ) { ExifMetadata.new( path: path, type: type ) }
  let( :exif ) { EXIFR::JPEG.new( path ).to_hash }

  context "with missing path and type options" do
    let( :path ) { nil }
    let( :type ) { nil }

    it { is_expected.to eq( {} ) }
  end

  context "with missing type option" do
    let( :type ) { nil }

    it { is_expected.to eq( {} ) }
  end

  context "with missing file" do
    let( :path ) { "./non-existent-file.jpg" }

    it { expect { subject }.to raise_error ExifMetadata::ExtractionError }
  end

  context "with JPEG file" do
    context "when extracting exif metadata" do
      it "should return metadata" do
        expect( subject[:gps_latitude] ).to eq exif[:gps_latitude]
        expect( subject[:gps_longitude] ).to eq exif[:gps_longitude]
        expect( subject[:date_time_original] ).to eq exif[:date_time_original]
      end

      it "should reject serial number tags" do
        expect( exif.keys ).to include( :lens_serial_number )
        expect( subject.keys ).to_not include( :lens_serial_number )
      end

      context "with malformed images" do
        let( :path ) { "spec/fixtures/files/cuthona_abronia-tagged.png" }

        it { expect { subject }.to raise_error EXIFR::MalformedImage }
      end
    end
  end

  context "with PNG file" do
    let( :type ) { "png" }
    let( :exif ) { Exiftool.new( path ).to_hash }

    context "when extracting tEXt/zTXt metadata" do
      let( :path ) { "spec/fixtures/files/polistes_dominula-png-metadata.png" }

      it "should return metadata" do
        expect( subject[:image_description] ).to eq exif[:description]
        expect( subject[:user_comment] ).to eq exif[:comment]
        expect( subject[:copyright] ).to eq exif[:copyright]
        expect( subject[:software] ).to eq exif[:software]
      end
    end

    context "when extracting exif metadata" do
      let( :path ) { "spec/fixtures/files/cuthona_abronia-tagged.png" }
      let( :time_format ) { "%Y:%m:%d %H:%M:%S" }

      it "should return metadata" do
        expect( subject[:gps_latitude] ).to eq exif[:gps_latitude]
        expect( subject[:gps_longitude] ).to eq exif[:gps_longitude]
        expect( subject[:date_time_original] ).to eq( Time.strptime( exif[:date_time_original], time_format ) )
      end

      it "should trim tags not included by EXIFR" do
        expect( ( subject.keys & EXIFR::TIFF::TAGS ).count ).to eq subject.keys.count
      end

      it "should cast date times to objects" do
        %i[date_time_digitized date_time_original modify_date].each do | dt |
          expect( subject[dt] ).to be_a( Time ) if subject[dt].present?
        end
      end

      it "should reject serial number tags" do
        expect( exif.keys ).to include( :lens_serial_number )
        expect( subject.keys ).to_not include( :lens_serial_number )
      end
    end
  end

  context "with Dublin Core metadata" do
    let( :dc ) { XMP.parse( EXIFR::JPEG.new( "spec/fixtures/files/cuthona_abronia-tagged.jpg" ) ).dc }

    it "should extract Dublin Core tags from XMP" do
      dc.attributes.each {| attr | expect( subject[:dc][attr.to_sym] ).to eq dc.send( attr ) }
    end
  end
end
