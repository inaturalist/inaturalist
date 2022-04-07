# frozen_string_literal: true

require "spec_helper"

describe LocalPhoto, "creation" do
  elastic_models( Observation )
  describe "creation" do
    it "should not set the native page url" do
      p = LocalPhoto.make!
      expect( p.native_page_url ).to be_blank
    end

    it "should not set the native_realname" do
      u = User.make!( name: "Hodor Hodor Hodor" )
      lp = LocalPhoto.make!( user: u )
      expect( lp.native_realname ).to be_blank
    end

    it "should set absolute image urls" do
      lp = LocalPhoto.make!
      expect( lp.small_url ).to be =~ /http/
    end

    it "requires user unless it has a subtype" do
      expect { LocalPhoto.make!( user: nil ) }.to raise_error( ActiveRecord::RecordInvalid )
      expect { LocalPhoto.make!( user: nil, subtype: "FlickrPhoto" ) }.to_not raise_error
    end

    it "sets native_photo id unless it has a subtype" do
      lp = LocalPhoto.make!
      expect( lp.native_photo_id ).to be_blank
      lp = LocalPhoto.make!( subtype: "FlickrPhoto", native_photo_id: "1234" )
      expect( lp.native_photo_id ).to eq "1234"
    end

    it "should not remove metadata" do
      p = LocalPhoto.new( )
      pm = PhotoMetadata.new( photo: p, metadata: { test_attr: "test_val" } )
      expect( p ).to receive( "file=" ).at_least( :once ).and_return( nil )
      p.file = { styles: { } }
      expect( p.metadata[:test_attr] ).to eq "test_val"
      p.extract_metadata( "some non-nil" )
      expect( p.metadata[:test_attr] ).to eq "test_val"
    end
  end

  describe "dimensions" do
    it "should extract dimension" do
      p = LocalPhoto.new( user: User.make! )
      p.file.assign( File.new( File.join( Rails.root, "app/assets/images/404mole.png" ) ) )
      expect( p.width ).to be nil
      expect( p.height ).to be nil
      p.extract_metadata
      expect( p.width ).to eq 600
      expect( p.height ).to eq 493
    end
  end

  it "can generate attribution without a user" do
    lp = LocalPhoto.make!( user: nil, subtype: "FlickrPhoto" )
    expect( lp.attribution ).to eq "(c) anonymous, all rights reserved"
  end
end

describe LocalPhoto, "to_observation" do
  elastic_models( Observation )

  context "JPEG" do
    it "should set a taxon from tags" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      t = Taxon.make!( name: "Cuthona abronia" )
      p.extract_metadata
      o = p.to_observation
      expect( o.taxon ).to eq( t )
    end

    it "should set a taxon from a file name" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia.jpg" ) )
      t = Taxon.make!( name: "Cuthona abronia" )
      o = p.to_observation
      expect( o.taxon ).to eq t
    end

    it "should not set a taxon based on an invalid name in the tags if a valid synonym exists" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      taxon_with_non_valid_name = Taxon.make!( rank: Taxon::SPECIES )
      taxon_with_valid_name = Taxon.make!( name: "Cuthona abronia", rank: Taxon::SPECIES )
      TaxonName.make!(
        taxon: taxon_with_non_valid_name,
        name: taxon_with_valid_name.name,
        is_valid: false,
        lexicon: TaxonName::SCIENTIFIC_NAMES
      )
      p.extract_metadata
      o = p.to_observation
      expect( o.taxon ).to eq taxon_with_valid_name
    end

    it "should not set a taxon from a blank title" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "spider-blank_title.jpg" ) )
      p.extract_metadata
      tn = TaxonName.make!
      tn.update_attribute( :name, "" )
      expect( tn.name ).to eq( "" )
      o = p.to_observation
      expect( o.taxon ).to be_blank
    end

    it "should not choose an inactive taxon if a current synonym exists" do
      active = Taxon.make!( name: "Neocuthona abronia", rank: Taxon::SPECIES )
      inactive = Taxon.make!( name: "Cuthona abronia", rank: Taxon::SPECIES, is_active: false )
      TaxonName.make!( taxon: active, name: inactive.name, lexicon: TaxonName::SCIENTIFIC_NAMES, is_valid: false )
      expect( active ).to be_is_active
      expect( inactive ).not_to be_is_active
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      p.extract_metadata
      o = p.to_observation
      expect( o.taxon ).to eq active
    end

    it "should set a taxon from a name in a language that matches the photo uploader's" do
      p = LocalPhoto.make( user: User.make!( locale: "es-MX" ) )
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "spider-blank_title.jpg" ) )
      tn = TaxonName.make!( lexicon: "Spanish", name: "spider" )
      o = p.to_observation
      expect( o.taxon ).to eq tn.taxon
    end

    it "should not set a taxon from a name in a language other than the photo uploader's" do
      p = LocalPhoto.make( user: User.make!( locale: "es-MX" ) )
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "spider-blank_title.jpg" ) )
      tn = TaxonName.make!( lexicon: "English", name: "spider" )
      o = p.to_observation
      expect( o.taxon ).not_to eq tn.taxon
    end

    it "should set positional_accuracy from the GPSHPositioningError tag" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "hyalophora-gps-h-pos.jpg" ) )
      p.extract_metadata
      o = p.to_observation
      expect( o.positional_accuracy ).not_to be_blank
    end

    it "should set positional_accuracy to zero if GPSHPositioningError is absent" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      p.extract_metadata
      o = p.to_observation
      expect( o.positional_accuracy ).not_to eq 0
      expect( o.positional_accuracy ).to be_nil
    end

    describe "time zone" do
      before(:all) { load_time_zone_geometries }
      after(:all) { unload_time_zone_geometries }

      it "should be set for a gecko in Malaysia" do
        p = build :local_photo
        p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "gecko-foot-malaysia.jpg" ) )
        p.extract_metadata
        o = p.to_observation
        expect( o.zic_time_zone ).to eq "Asia/Kuala_Lumpur"
        expect( o.time_observed_at_in_zone.hour ).to eq 22
      end

      it "should be set for a gecko in Malaysia if observer time zone is Hawaii" do
        p = build( :local_photo, user: create( :user, time_zone: "Hawaii" ) )
        p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "gecko-foot-malaysia.jpg" ) )
        p.extract_metadata
        o = p.to_observation
        expect( o.user.time_zone ).to eq "Hawaii"
        expect( o.zic_time_zone ).to eq "Asia/Kuala_Lumpur"
        expect( o.time_observed_at_in_zone.hour ).to eq 22
      end

      it "should be set for a gecko in Malaysia if operating time zone is PST" do
        Time.use_zone( "America/Los_Angeles" ) do
          p = build :local_photo
          p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "gecko-foot-malaysia.jpg" ) )
          p.extract_metadata
          o = p.to_observation
          expect( o.zic_time_zone ).to eq "Asia/Kuala_Lumpur"
          expect( o.time_observed_at_in_zone.hour ).to eq 22
        end
      end
    end
  end

  context "PNG" do
    it "should extract select PNG tEXt/zTXt metadata" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "polistes_dominula-png-metadata.png" ) )
      p.extract_metadata
      o = p.to_observation
      expect( o.description ).to eq "Paper Wasp"
    end

    it "should extract exif metadata" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.png" ) )
      p.extract_metadata
      o = p.to_observation
      expect( o.observed_on_string ).to eq p.metadata[:date_time_original].strftime( "%Y-%m-%d %H:%M:%S" )
      expect( o.latitude ).to eq p.metadata[:gps_latitude].to_d
      expect( o.longitude ).to eq p.metadata[:gps_longitude].to_d
    end

    it "should set a taxon from a file name" do
      p = LocalPhoto.make
      p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "polistes_dominula-png-metadata.png" ) )
      t = Taxon.make!( name: "Polistes dominula" )
      o = p.to_observation
      expect( o.taxon ).to eq t
    end
  end

  context "Dublin Core" do
    it "should set observation fields from machine tags" do
      of = ObservationField.make!( name: "sex", allowed_values: "unknown|male|female",
        datatype: ObservationField::TEXT )
      lp = LocalPhoto.make!
      pm = PhotoMetadata.new( photo: lp, metadata: {
        dc: {
          subject: ["sex=female"]
        }
      })
      o = lp.to_observation
      expect( o.observation_field_values.detect { |ofv| ofv.observation_field_id == of.id }.value ).to eq "female"
    end

    it "should not set invalid observation fields from machine tags" do
      of = ObservationField.make!( name: "sex", allowed_values: "unknown|male|female",
        datatype: ObservationField::TEXT )
      lp = LocalPhoto.make!
      pm = PhotoMetadata.new( photo: lp, metadata: {
        dc: {
          subject: ["sex=whatevs"]
        }
      })
      o = lp.to_observation
      puts "o.errors: #{o.errors.full_messages.to_sentence}" unless o.valid?
      expect( o ).to be_valid
      expect( o.observation_field_values.detect { |ofv| ofv.observation_field_id == of.id } ).to be_blank
    end

    it "should add arbitrary tags from keywords" do
      lp = LocalPhoto.make!
      pm = PhotoMetadata.new( photo: lp, metadata: {
        dc: {
          subject: ["tag1", "tag2"]
        }
      })
      o = lp.to_observation
      expect( o.tag_list ).to include "tag1"
      expect( o.tag_list ).to include "tag2"
    end

    it "should not import branded descriptions" do
      LocalPhoto::BRANDED_DESCRIPTIONS.each do | branded_description |
        lp = LocalPhoto.make!
        pm = PhotoMetadata.new( photo: lp, metadata: {
          dc: {
            description: branded_description
          }
        })
        o = lp.to_observation
        expect( o.description ).to be_blank
      end
    end
  end
end

describe LocalPhoto, "flagging" do
  elastic_models( Observation )
  let( :lp ) { LocalPhoto.make! }
  it "should change the value returned by URL methods for copyright infringement" do
    Flag.make!( flaggable: lp, flag: Flag::COPYRIGHT_INFRINGEMENT )
    lp.reload
    %w(original large medium small thumb square).each do | size |
      expect( lp.send( "#{size}_url" ) ).to be =~ /copyright/
    end
  end
  it "should not change the actual photo URLs for copyright infringement" do
    Flag.make!( flaggable: lp, flag: Flag::COPYRIGHT_INFRINGEMENT )
    lp.reload
    %w(original large medium small thumb square).each do | size |
      expect( lp["#{size}_url"] ).not_to be =~ /copyright/
    end
  end
  it "should not change URL method return values unless the flag was for copyright" do
    Flag.make!( flaggable: lp, flag: Flag::COPYRIGHT_INFRINGEMENT )
    f2 = Flag.make!( flaggable: lp, flag: Flag::SPAM )
    lp.reload
    f2.update( resolved: true, resolver: User.make! )
    lp.reload
    %w(original large medium small thumb square).each do | size |
      expect( lp.send( "#{size}_url" ) ).to be =~ /copyright/
    end
  end
  it "should change make associated observations casual grade when flagged" do
    o = make_research_grade_candidate_observation
    expect( o.quality_grade ).to eq Observation::NEEDS_ID
    Flag.make!( flaggable: o.photos.first, flag: Flag::COPYRIGHT_INFRINGEMENT )
    Delayed::Worker.new.work_off
    o.reload
    expect( o.quality_grade ).to eq Observation::CASUAL
  end

  # I don't know how to test this now that we reprocess files when repairing - kueda 20160715
  # I added more things I can't test ~~kueda 20200811
  # describe "resolution" do
  #   let(:o) {
  #     o = Observation.make!( latitude: 1, longitude: 1, observed_on_string: "yesterday" )
  #     p = LocalPhoto.make( user: o.user )
  #     p.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
  #     o.photos << p
  #     Observation.set_quality_grade( o.id )
  #     o.reload
  #     o
  #   }
  #   let(:flag) { Flag.make!( flaggable: o.photos.first, flag: Flag::COPYRIGHT_INFRINGEMENT ) }
  #   before do
  #     @obs = flag.flaggable.observation_photos.first.observation
  #     Delayed::Worker.new.work_off
  #     @obs.reload
  #     expect( @obs.quality_grade ).to eq Observation::CASUAL
  #   end
  #   it "should change the URLs back when resolved" do
  #     photo = flag.flaggable
  #     expect( photo.original_url ).to be =~ /copyright/
  #     flag.update( resolved: true, resolver: User.make! )
  #     photo.reload
  #     %w(original large medium small thumb square).each do |size|
  #       expect( lp.send( "#{size}_url" ) ).not_to be =~ /copyright/
  #     end
  #   end
  #   it "should revert quality grade" do
  #     flag.update( resolved: true, resolved_at: Time.now, resolver: make_curator, comment: "foo" )
  #     Delayed::Worker.new.work_off
  #     expect( flag ).to be_resolved
  #     @obs.reload
  #     expect( @obs.quality_grade ).to eq Observation::NEEDS_ID
  #   end
  #   it "should not revert quality grade if there's another unresolved copyright flag" do
  #     other_flag = Flag.make!( flaggable: o.photos.first, flag: Flag::COPYRIGHT_INFRINGEMENT )
  #     flag.update( resolved: true, resolved_at: Time.now, resolver: make_curator, comment: "foo" )
  #     Delayed::Worker.new.work_off
  #     expect( flag ).to be_resolved
  #     @obs.reload
  #     expect( @obs.quality_grade ).to eq Observation::CASUAL
  #   end
  # end
  it "should re-index the observation" do
    o = make_research_grade_observation
    original_last_indexed_at = o.last_indexed_at
    without_delay { Flag.make!( flaggable: o.photos.first, flag: Flag::COPYRIGHT_INFRINGEMENT ) }
    o.reload
    expect( o.last_indexed_at ).to be > original_last_indexed_at
  end
end

describe LocalPhoto do
  it "uses subtype for source_title if available" do
    lp = LocalPhoto.new
    expect( lp.source_title ).to eq Site.default.name
    lp = LocalPhoto.new( subtype: "FlickrPhoto" )
    expect( lp.source_title ).to eq "Flickr"
  end
end
