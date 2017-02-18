require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonSplit, "validation" do
  it "should not allow the same taxon on both sides of the split" do
    old_taxon = Taxon.make!( rank: Taxon::FAMILY )
    new_taxon = Taxon.make!( rank: Taxon::FAMILY )
    tc = TaxonSplit.make
    tc.add_input_taxon(old_taxon)
    tc.add_output_taxon(new_taxon)
    tc.add_output_taxon(old_taxon)
    tc.save
    expect(tc).not_to be_valid
  end

  it "should now allow a split with only one output" do
    tc = TaxonSplit.make
    tc.add_input_taxon( Taxon.make! )
    tc.add_output_taxon( Taxon.make! )
    expect( tc ).not_to be_valid
  end
end

describe TaxonSplit, "commit" do
  before(:each) { prepare_split }

  it "should generate updates for observers of the old taxon"
  it "should generate updates for identifiers of the old taxon"
  it "should generate updates for listers of the old taxon"

  it "should mark the input taxon as inactive" do
    @split.commit
    @input_taxon.reload
    expect(@input_taxon).not_to be_is_active
  end

  it "should mark the output taxon as active" do
    @split.commit
    @output_taxon1.reload
    expect(@output_taxon1).to be_is_active
    @output_taxon2.reload
    expect(@output_taxon2).to be_is_active
  end
end

describe TaxonSplit, "commit_records" do
  before(:each) { prepare_split }
  before(:each) { enable_elastic_indexing( Observation, Identification ) }
  after(:each) { disable_elastic_indexing( Observation, Identification ) }

  it "should not update records if one of the output taxa isn't atlased" do
    @split.output_taxa.each do |t|
      expect( t ).not_to be_atlased
    end
    obs = Observation.make!( taxon: @input_taxon )
    @split.commit_records
    obs.reload
    expect( obs.taxon ).to eq( @input_taxon )
  end

  describe "with atlased taxa" do

    let( :presence_place1 ) {
      make_place_with_geom(
        wkt: "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))",
        place_type: Place::COUNTRY,
        admin_level: Place::COUNTRY_LEVEL
      )
    }
    let( :presence_place2 ) {
      make_place_with_geom(
        wkt: "MULTIPOLYGON(((1 1,1 2,2 2,2 1,1 1)))",
        place_type: Place::COUNTRY,
        admin_level: Place::COUNTRY_LEVEL
      )
    }
    let( :absence_place ) {
      make_place_with_geom(
        wkt: "MULTIPOLYGON(((0 0,0 -1,-1 -1,-1 0,0 0)))",
        place_type: Place::COUNTRY,
        admin_level: Place::COUNTRY_LEVEL
      )
    }

    describe "that have non-overlapping presence places" do
      before do
        atlas1 = @split.output_taxa[0]
        atlas1 = make_atlas_with_presence( taxon: @split.output_taxa[0], place: presence_place1 )
        expect( atlas1.presence_places ).to include presence_place1
        expect( atlas1.presence_places ).not_to include presence_place2
        atlas2 = @split.output_taxa[1]
        atlas2 = make_atlas_with_presence( taxon: @split.output_taxa[1], place: presence_place2 )
        expect( atlas2.presence_places ).to include presence_place2
        expect( atlas2.presence_places ).not_to include presence_place1
        @split.reload
      end
      describe "identifications" do
        before do
          @observation = without_delay do
            Observation.make!(
              taxon: @split.input_taxon,
              latitude: presence_place1.latitude,
              longitude: presence_place1.longitude
            )
          end
          PlaceDenormalizer.denormalize
          @observation.reload
          expect( @observation.observations_places ).not_to be_blank
          @identification = @observation.identifications.first
          expect( @identification.taxon ).to eq @split.input_taxon
        end
        it "should be made not current" do
          expect( @identification ).to be_current
          @split.commit_records
          @identification.reload
          expect( @identification ).not_to be_current
        end
        it "should be replaced with identifications of the output taxon" do
          output_taxon = @split.output_taxon_for_record( @observation )
          expect(
            @observation.identifications.current.of( output_taxon ).by( @identification.user_id ).first
          ).to be_blank
          @split.commit_records
          @observation.reload
          expect(
            @observation.identifications.current.of( output_taxon ).by( @identification.user_id ).first
          ).not_to be_blank
        end
        it "should not be replaced if the observation has no coordinates" do
          @observation.update_attributes( latitude: nil, longitude: nil )
          expect( @split.output_taxon_for_record( @observation ) ).to be_blank
          prev_ident_count = @observation.identifications.size
          @split.commit_records
          @observation.reload
          expect( @observation.identifications.size ).to eq prev_ident_count
        end
      end
      describe "observations" do
        it "should change the taxon if coordinates are in a non-overlapping presence place" do
          o = Observation.make!(
            latitude: presence_place1.latitude,
            longitude: presence_place1.longitude,
            taxon: @split.input_taxon
          )
          @split.commit_records
          o.reload
          expect( o.taxon ).to eq @split.output_taxa[0]
        end
        it "should not change the taxon if the obs is of a competely different taxon" do
          t = Taxon.make!
          o = Observation.make!(
            latitude: presence_place1.latitude,
            longitude: presence_place1.longitude,
            taxon: t
          )
          @split.commit_records
          o.reload
          expect( o.taxon ).to eq t
        end
        it "should not change the taxon if the coordinates are outside both output atlases" do
          o = Observation.make!(
            latitude: presence_place1.latitude * 10 ,
            longitude: presence_place1.longitude * 10 ,
            taxon: @split.input_taxon
          )
          expect( o.system_places ).not_to include presence_place1
          expect( o.system_places ).not_to include presence_place2
          @split.commit_records
          o.reload
          expect( o.taxon ).to eq @split.input_taxon
        end
      end
      describe "listed taxa" do
        it "should change the taxon if the place is a non-overlapping presence place" do
          lt = make_check_listed_taxon( taxon: @split.input_taxon, place: presence_place1 )
          @split.commit_records
          lt.reload
          expect( lt.taxon ).to eq @split.output_taxa[0]
        end
        it "should change the taxon if the place descends from a non-overlapping presence place" do
          descendant_place = Place.make!( parent: presence_place1 )
          lt = descendant_place.check_list.add_taxon( @split.input_taxon )
          @split.commit_records
          lt.reload
          expect( lt.taxon ).to eq @split.output_taxa[0]
        end
        it "should not change the taxon if the place is an ancestor of a non-overlapping presence place" do
          ancestor_place = Place.make!
          presence_place1.update_attributes( parent: ancestor_place )
          lt = ancestor_place.check_list.add_taxon( @split.input_taxon )
          @split.commit_records
          lt.reload
          expect( lt.taxon ).not_to eq @split.output_taxa[0]
        end
        it "should not change the taxon if the place is outside of both output atlases" do
          lt = make_check_listed_taxon
          @split.commit_records
          lt.reload
          expect( lt.taxon ).not_to eq @split.output_taxa[0]
        end
      end
    end
    describe "that have an overlapping presence place" do
      before do
        atlas1 = @split.output_taxa[0]
        atlas1 = make_atlas_with_presence( taxon: @split.output_taxa[0], place: presence_place1 )
        expect( atlas1.presence_places ).to include presence_place1
        presence_place2.check_list.add_taxon( @split.output_taxa[0] )
        expect( atlas1.presence_places ).to include presence_place2
        atlas2 = @split.output_taxa[1]
        atlas2 = make_atlas_with_presence( taxon: @split.output_taxa[1], place: presence_place1 )
        expect( atlas2.presence_places ).to include presence_place1
        @split.reload
      end
      describe "identifications" do
        it "should not be affected for observations in the overlapping place" do
          observation = without_delay do
            Observation.make!(
              taxon: @split.input_taxon,
              latitude: presence_place1.latitude,
              longitude: presence_place1.longitude
            )
          end
          PlaceDenormalizer.denormalize
          observation.reload
          expect( observation.observations_places ).not_to be_blank
          identification = observation.identifications.first
          expect( identification.taxon ).to eq @split.input_taxon
          expect( identification ).to be_current
          @split.commit_records
          identification.reload
          expect( identification ).to be_current
        end
        it "should still be made not current in non-overlapping places" do
          observation = without_delay do
            Observation.make!(
              taxon: @split.input_taxon,
              latitude: presence_place2.latitude,
              longitude: presence_place2.longitude
            )
          end
          PlaceDenormalizer.denormalize
          observation.reload
          expect( observation.observations_places ).not_to be_blank
          identification = observation.identifications.first
          expect( identification.taxon ).to eq @split.input_taxon
          expect( identification ).to be_current
          @split.commit_records
          identification.reload
          expect( identification ).not_to be_current
        end
      end
      describe "observations" do
        it "should change the taxon if coordinates are in a non-overlapping presence place" do
          o = Observation.make!(
            latitude: presence_place2.latitude,
            longitude: presence_place2.longitude,
            taxon: @split.input_taxon
          )
          @split.commit_records
          o.reload
          expect( o.taxon ).to eq @split.output_taxa[0]
        end
        it "should not change the taxon if coordinates are in an overlapping presence place" do
          o = Observation.make!(
            latitude: presence_place1.latitude,
            longitude: presence_place1.longitude,
            taxon: @split.input_taxon
          )
          @split.commit_records
          o.reload
          expect( o.taxon ).to eq @split.input_taxon
        end
        it "should not change the taxon if the coordinates are outside both output atlases" do
          o = Observation.make!(
            latitude: presence_place1.latitude * 10 ,
            longitude: presence_place1.longitude * 10 ,
            taxon: @split.input_taxon
          )
          expect( o.system_places ).not_to include presence_place1
          expect( o.system_places ).not_to include presence_place2
          @split.commit_records
          o.reload
          expect( o.taxon ).to eq @split.input_taxon
        end
      end
    end
  end
end

def prepare_split
  @input_taxon = Taxon.make!( rank: Taxon::FAMILY )
  @output_taxon1 = Taxon.make!( rank: Taxon::FAMILY )
  @output_taxon2 = Taxon.make!( rank: Taxon::FAMILY )
  @split = TaxonSplit.make
  @split.add_input_taxon(@input_taxon)
  @split.add_output_taxon(@output_taxon1)
  @split.add_output_taxon(@output_taxon2)
  @split.save!
end
