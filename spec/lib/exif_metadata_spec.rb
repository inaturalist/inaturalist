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

  context "with Dublin Core metadata in XMP" do
    it "should extract a subject bag" do
      expect( subject[:dc] ).to eq( subject: ["Cuthona abronia"] )
    end

    context "with seq and alt arrays" do
      let( :path ) { "spec/fixtures/files/gecko-foot-malaysia.jpg" }

      it "should extract every dc element" do
        expect( subject[:dc] ).to eq(
          creator: ["Tony Iwane"],
          description: [" " * 31],
          rights: ["Tony Iwane"],
          subject: ["penang", "malaysia", "penang island", "lizard", "gekko smithii", "giant forest gecko"]
        )
      end
    end

    context "with an inline dc attribute" do
      let( :path ) { "spec/fixtures/files/spider-blank_title.jpg" }

      it "should extract attributes and elements" do
        expect( subject[:dc] ).to eq( format: "image/jpeg", title: [" "] )
      end
    end

    context "with a padded scalar dc element" do
      before do
        xmp = <<~XML
          <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/">
              <dc:format>
                image/jpeg
              </dc:format>
            </rdf:Description>
          </rdf:RDF></x:xmpmeta>
        XML
        allow( EXIFR::JPEG ).to receive( :new ).and_return(
          instance_double( EXIFR::JPEG, to_hash: {}, app1s: ["http://ns.adobe.com/xap/1.0/\0#{xmp}"] )
        )
      end

      it "should strip the value" do
        expect( subject[:dc] ).to eq( format: "image/jpeg" )
      end
    end

    context "with XMP but no dc namespace" do
      let( :path ) { "spec/fixtures/files/hyalophora-gps-h-pos.jpg" }

      it { is_expected.not_to have_key( :dc ) }
    end

    context "without XMP" do
      let( :path ) { "spec/fixtures/files/cuthona_abronia.jpg" }

      it { is_expected.not_to have_key( :dc ) }
    end

    it "should not write files to the working directory" do
      absolute_path = File.expand_path( path )
      Dir.mktmpdir do | dir |
        Dir.chdir( dir ) { ExifMetadata.new( path: absolute_path, type: type ).extract }
        expect( Dir.children( dir ) ).to be_empty
      end
    end
  end
end
