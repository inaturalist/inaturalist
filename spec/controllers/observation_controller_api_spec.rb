# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "ObservationsController basics" do
  describe "create" do
    elastic_models( Observation )
    it "should create" do
      expect do
        post :create, format: :json, params: { observation: { species_guess: "foo" } }
      end.to change( Observation, :count ).by( 1 )
      o = Observation.last
      expect( o.user_id ).to eq( user.id )
      expect( o.species_guess ).to eq( "foo" )
    end
    it "should not create for a suspended user" do
      user.suspend!
      expect do
        post :create, format: :json, params: { observation: { species_guess: "foo" } }
      end.not_to change( Observation, :count )
    end
    it "should create for an unsuspended user" do
      user.suspend!
      user.unsuspend!
      expect do
        post :create, format: :json, params: { observation: { species_guess: "foo" } }
      end.to change( Observation, :count )
    end
  end

  describe "destroy" do
    it "should destroy" do
      o = Observation.make!( user: user )
      delete :destroy, format: :json, params: { id: o.id }
      expect( Observation.find_by_id( o.id ) ).to be_blank
    end
    it "should not be possible for non-observers" do
      o = Observation.make!( user: User.make! )
      delete :destroy, format: :json, params: { id: o.id }
      expect( Observation.find_by_id( o.id ) ).not_to be_blank
    end
    it "should be possible for staff on other people's observations" do
      o = Observation.make!( user: User.make! )
      user.roles << Role.make!( name: User::JEDI_MASTER_ROLE )
      user.reload
      delete :destroy, format: :json, params: { id: o.id }
      expect( Observation.find_by_id( o.id ) ).to be_blank
    end
  end

  describe "update" do
    let( :o ) { Observation.make!( user: user ) }
    it "should update" do
      put :update, format: :json, params: { id: o.id, observation: { species_guess: "i am so updated" } }
      o.reload
      expect( o.species_guess ).to eq "i am so updated"
    end
  end
end

shared_examples_for "an ObservationsController" do
  describe "create" do
    elastic_models( Observation, Identification )

    it "should create with an existing photo ID" do
      p = LocalPhoto.make!( user: user )
      3.times do
        post :create, format: :json, params: { observation: {
          taxon_id: Taxon.make!.id,
          latitude: 1.2345,
          longitude: 1.2345
        }, local_photos: { "0" => p.id } }
      end
      o = user.observations.last
      expect( o.photos ).to include p
    end

    it "should not unset the taxon if existing photo included" do
      t = Taxon.make!
      p = LocalPhoto.make!( user: user )
      post :create, format: :json, params: { observation: { taxon_id: t.id }, local_photos: { "0" => p.id } }
      o = user.observations.last
      expect( o.taxon ).to eq t
    end

    it "should include coordinates in create response when geoprivacy is obscured" do
      post :create, format: :json, params: { observation: {
        latitude: 1.2345,
        longitude: 1.2345,
        geoprivacy: Observation::OBSCURED
      } }
      o = Observation.last
      expect( o ).to be_coordinates_obscured
      expect( response.body ).to be =~ /#{o.latitude}/
      expect( response.body ).to be =~ /#{o.longitude}/
    end

    it "should include private coordinates in create response when geoprivacy is obscured" do
      post :create, format: :json, params: { observation: {
        latitude: 1.2345,
        longitude: 1.2345,
        geoprivacy: Observation::OBSCURED
      } }
      o = Observation.last
      expect( o ).to be_coordinates_obscured
      expect( response.body ).to be =~ /#{o.private_latitude}/
      expect( response.body ).to be =~ /#{o.private_longitude}/
    end

    it "should include private coordinates in create response when geoprivacy is private" do
      post :create, format: :json, params: { observation: {
        latitude: 1.2345,
        longitude: 1.2345,
        geoprivacy: Observation::PRIVATE
      } }
      o = Observation.last
      expect( o.latitude ).to be_blank
      expect( o.private_latitude ).not_to be_blank
      expect( response.body ).to be =~ /#{o.private_latitude}/
      expect( response.body ).to be =~ /#{o.private_longitude}/
    end

    it "should not fail if species_guess is a question mark" do
      post :create, format: :json, params: { observation: { species_guess: "?" } }
      expect( response ).to be_successful
      o = Observation.last
      expect( o.species_guess ).to eq( "?" )
    end

    it "should accept nested observation_field_values" do
      of = ObservationField.make!
      post :create, format: :json, params: { observation: {
        species_guess: "zomg",
        observation_field_values_attributes: [
          {
            observation_field_id: of.id,
            value: "foo"
          }
        ]
      } }
      expect( response ).to be_successful
      o = Observation.last
      expect( o.observation_field_values.last.observation_field ).to eq( of )
      expect( o.observation_field_values.last.value ).to eq( "foo" )
    end

    it "should survive blank observation_field_values_attributes" do
      expect do
        post :create, format: :json, params: { observation: {
          observation_field_values_attributes: ""
        } }
      end.not_to raise_error
    end

    it "should not fail with a dot for a species_guess" do
      expect do
        post :create, format: :json, params: { observation: { species_guess: "." } }
      end.not_to raise_error
    end

    describe "time_zone" do
      it "should not raise an error when unrecognized" do
        expect do
          post :create, format: :json, params: { observation: {
            species_guess: "foo",
            observed_on_string: "2014-07-01 14:23",
            time_zone: "Eastern Time (US &amp; Canada)"
          } }
        end.not_to raise_error
      end
      it "should accept Rails time zone names" do
        tz = ActiveSupport::TimeZone["Baghdad"]
        post :create, format: :json, params: { observation: {
          observed_on_string: "2020-03-01 00:00",
          time_zone: tz.name
        } }
        o = Observation.last
        expect( o.time_zone ).to eq tz.name
      end
      it "should accept TZInfo time zone names" do
        tz = ActiveSupport::TimeZone["Baghdad"]
        post :create, format: :json, params: { observation: {
          observed_on_string: "2020-03-01 00:00",
          time_zone: tz.tzinfo.name
        } }
        o = Observation.last
        expect( o.time_zone ).to eq tz.name
        expect( o.zic_time_zone ).to eq tz.tzinfo.name
      end
      it "should accept TZInfo time zone names when observed_on_string is an ISO 8601 formtted datetime" do
        zone_name = "Baghdad"
        zic_zone_name = "Asia/Baghdad"
        tz = ActiveSupport::TimeZone[zone_name]
        post :create, format: :json, params: { observation: {
          observed_on_string: "2021-03-24T14:40:25",
          time_zone: zic_zone_name
        } }
        o = Observation.last
        expect( o.time_zone ).to eq tz.name
        expect( o.zic_time_zone ).to eq tz.tzinfo.name
        expect( o.time_observed_at_in_zone.hour ).to eq 14
      end
      it "should override the user's time zone" do
        tz = ActiveSupport::TimeZone["Baghdad"]
        expect( user.time_zone ).not_to be_blank
        expect( user.time_zone ).not_to eq tz.name
        post :create, format: :json, params: { observation: {
          observed_on_string: "2020-03-01 23:00",
          time_zone: tz.name
        } }
        o = Observation.last
        expect( o.time_zone ).to eq tz.name
      end
    end

    describe "project_id" do
      let( :p ) { Project.make! }

      it "should add to project" do
        post :create, format: :json, params: { observation: { species_guess: "foo" }, project_id: p.id }
        expect( p.observations.count ).to eq 1
      end

      it "should not create a project user if one doesn't exist" do
        expect( p.project_users.where( user_id: user.id ) ).to be_blank
        post :create, format: :json, params: { observation: { species_guess: "foo" }, project_id: p.id }
        p.reload
        expect( p.project_users.where( user_id: user.id ) ).to be_blank
      end

      describe "if photo present" do
        it "should add to project with has_media rule" do
          photo = LocalPhoto.make!( user: user )
          project = Project.make!
          ProjectObservationRule.make!( ruler: project, operator: "has_media?" )
          post :create, format: :json, params: {
            project_id: project.id,
            observation: { species_guess: "foo" },
            local_photos: {
              "0" => photo.id
            }
          }
          o = user.observations.last
          expect( o.projects ).to include( project )
        end
      end

      it "should set the project_observation's user_id" do
        post :create, format: :json, params: { observation: { species_guess: "foo" }, project_id: p.id }
        po = user.observations.last.project_observations.where( project_id: p.id ).first
        expect( po.user_id ).to eq user.id
      end
    end

    it "should not duplicate observations with the same uuid" do
      uuid = SecureRandom.uuid
      Observation.make!( user: user, uuid: uuid )
      post :create, format: :json, params: { observation: { uuid: uuid } }
      expect( Observation.where( uuid: uuid ).count ).to eq 1
    end

    it "should update attributes for an existing observation with the same uuid" do
      uuid = SecureRandom.uuid
      o = Observation.make!( user: user, uuid: uuid )
      post :create, format: :json, params: { observation: { uuid: uuid, description: "this is a WOAH" } }
      expect( Observation.where( uuid: uuid ).count ).to eq 1
      o.reload
      expect( o.description ).to eq "this is a WOAH"
    end

    it "should be invalid for observations with the same uuid if the existing was by a differnet user" do
      uuid = SecureRandom.uuid
      Observation.make!( uuid: uuid )
      post :create, format: :json, params: { observation: { uuid: uuid } }
      expect( response.status ).to eq 422
      expect( Observation.where( uuid: uuid ).count ).to eq 1
    end

    describe "with uuid of existing observation" do
      let( :existing ) { Observation.make!( user: user ) }
      it "should ignore photos if no photos specified" do
        ObservationPhoto.make!( observation: existing, photo: LocalPhoto.make!( user: user ) )
        existing.reload
        expect( existing.photos.size ).to eq 1
        post :create, format: :json, params: { observation: { uuid: existing.uuid } }
        existing.reload
        expect( existing.photos.size ).to eq 1
      end
      it "should use photos if photos specified" do
        expect( existing.photos.size ).to eq 0
        p = LocalPhoto.make!( user: user )
        post :create, format: :json, params: { observation: { uuid: existing.uuid }, local_photos: { "0" => p.id } }
        existing.reload
        expect( existing.photos.size ).to eq 1
      end
      it "should not create duplicate observation photos" do
        op = ObservationPhoto.make!( observation: existing, photo: LocalPhoto.make!( user: user ) )
        existing.reload
        expect( existing.observation_photos.size ).to eq 1
        post :create, format: :json, params: {
          observation: { uuid: existing.uuid },
          local_photos: { "0" => op.photo_id }
        }
        existing.reload
        expect( existing.observation_photos.size ).to eq 1
      end
    end

    it "should set the uuid even if it wasn't included in the request" do
      post :create, format: :json, params: { observation: { species_guess: "foo" } }
      json = JSON.parse( response.body )[0]
      expect( json["uuid"] ).not_to be_blank
    end

    it "should not override a uuid in the request" do
      uuid = SecureRandom.uuid
      post :create, format: :json, params: { observation: { uuid: uuid } }
      json = JSON.parse( response.body )[0]
      expect( json["uuid"] ).to eq uuid
    end

    it "should default to using Site.default" do
      post :create, format: :json, params: { observation: { uuid: SecureRandom.uuid } }
      json = JSON.parse( response.body )[0]
      expect( json["site_id"] ).to eq Site.default.id
    end

    it "should accept other site_ids" do
      newsite = Site.make!
      post :create, format: :json, params: { observation: { uuid: SecureRandom.uuid, site_id: newsite.id } }
      json = JSON.parse( response.body )[0]
      expect( json["site_id"] ).to eq newsite.id
    end

    describe "with owners_identification_from_vision" do
      it "should set mark the owners identification as coming from vision" do
        post :create, format: :json, params: {
          observation: { taxon_id: Taxon.make!.id, owners_identification_from_vision: true }
        }
        json = JSON.parse( response.body )[0]
        o = Observation.find( json["id"] )
        expect( o.owners_identification_from_vision ).to be true
        expect( o.owners_identification.vision ).to be true
      end
      it "should return the same attribute and value" do
        post :create, format: :json, params: {
          observation: { taxon_id: Taxon.make!.id, owners_identification_from_vision: true }
        }
        json = JSON.parse( response.body )[0]
        expect( json["owners_identification_from_vision"] ).to be true
      end
    end

    it "should not allow observations where latitude AND longitude are 0" do
      post :create, format: :json, params: { observation: { latitude: 0, longitude: 0 } }
      expect( response.status ).to eq 422
    end

    it "should assign a taxon by UUID" do
      t = Taxon.make!
      post :create, format: :json, params: { observation: { taxon_id: t.uuid } }
      expect( user.observations.last.taxon ).to eq t
    end
  end

  describe "destroy" do
    it "should not destory other people's observations" do
      o = Observation.make!
      delete :destroy, format: :json, params: { id: o.id }
      expect( Observation.find_by_id( o.id ) ).not_to be_blank
    end
  end

  describe "show" do
    elastic_models( Observation )

    it "should provide private coordinates for user's observation" do
      o = Observation.make!( user: user, latitude: 1.23456, longitude: 7.890123, geoprivacy: Observation::PRIVATE )
      get :show, format: :json, params: { id: o.id }
      expect( response.body ).to be =~ /#{o.private_latitude}/
      expect( response.body ).to be =~ /#{o.private_longitude}/
    end

    it "should include private coordinates when project curator coordinate access has been granted" do
      o = Observation.make!( latitude: 1.23456, longitude: 7.890123, geoprivacy: Observation::PRIVATE )
      po = ProjectObservation.make!( observation: o, prefers_curator_coordinate_access: true )
      ProjectUser.make!( user: user, project: po.project, role: ProjectUser::CURATOR )
      o.reload
      expect( o ).to be_coordinates_viewable_by( user )
      get :show, format: :json, params: { id: o.id }
      expect( response.body ).to be =~ /#{o.private_latitude}/
      expect( response.body ).to be =~ /#{o.private_longitude}/
    end

    it "should not provide private coordinates for another user's observation" do
      o = Observation.make!( latitude: 1.23456, longitude: 7.890123, geoprivacy: Observation::PRIVATE )
      get :show, format: :json, params: { id: o.id }
      expect( response.body ).not_to be =~ /#{o.private_latitude}/
      expect( response.body ).not_to be =~ /#{o.private_longitude}/
    end

    it "should not include photo metadata" do
      p = LocalPhoto.make!( )
      pm = PhotoMetadata.make!( photo: p, metadata: { foo: "bar" } )
      expect( p.metadata ).not_to be_blank
      o = Observation.make!( user: p.user, taxon: Taxon.make! )
      make_observation_photo( photo: p, observation: o )
      get :show, format: :json, params: { id: o.id }
      response_obs = JSON.parse( response.body )
      response_photo = response_obs["observation_photos"][0]["photo"]
      expect( response_photo ).not_to be_blank
      expect( response_photo["metadata"] ).to be_blank
    end

    it "should include observation field values" do
      ofv = ObservationFieldValue.make!
      get :show, format: :json, params: { id: ofv.observation_id }
      response_obs = JSON.parse( response.body )
      expect( response_obs["observation_field_values"].first["value"] ).to eq( ofv.value )
    end

    it "should include observation field values with observation field names" do
      ofv = ObservationFieldValue.make!
      get :show, format: :json, params: { id: ofv.observation_id }
      response_obs = JSON.parse( response.body )
      expect(
        response_obs["observation_field_values"].first["observation_field"]["name"]
      ).to eq( ofv.observation_field.name )
    end

    it "should include comments" do
      o = Observation.make!
      c = Comment.make!( parent: o )
      get :show, format: :json, params: { id: o.id }
      response_obs = JSON.parse( response.body )
      expect( response_obs["comments"].first["body"] ).to eq( c.body )
    end

    it "should include comment user icons" do
      o = Observation.make!
      c = Comment.make!( parent: o )
      File.open( "#{File.dirname( __FILE__ )}/../fixtures/files/egg.jpg" ) do | f |
        c.user.update( icon: f )
      end
      get :show, format: :json, params: { id: o.id }
      response_obs = JSON.parse( response.body )
      expect( response_obs["comments"].first["user"]["user_icon_url"] ).not_to be_blank
    end

    it "should include identifications" do
      o = Observation.make!
      i = Identification.make!( observation: o )
      get :show, format: :json, params: { id: o.id }
      response_obs = JSON.parse( response.body )
      expect( response_obs["identifications"].first["taxon_id"] ).to eq( i.taxon_id )
    end

    it "should include identification user icons" do
      o = Observation.make!
      i = Identification.make!( observation: o )
      File.open( "#{File.dirname( __FILE__ )}/../fixtures/files/egg.jpg" ) do | f |
        i.user.update( icon: f )
      end
      get :show, format: :json, params: { id: o.id }
      response_obs = JSON.parse( response.body )
      expect( response_obs["identifications"].first["user"]["user_icon_url"] ).not_to be_blank
    end

    it "should include identification taxon icons" do
      load_test_taxa
      o = Observation.make!
      Taxon.make!( iconic_taxon: @Amphibia )
      Identification.make!( observation: o )
      get :show, format: :json, params: { id: o.id }
      response_obs = JSON.parse( response.body )
      expect( response_obs["identifications"].first["taxon"]["image_url"] ).not_to be_blank
    end

    it "should include identification taxon common name" do
      tn = TaxonName.make!( lexicon: "English" )
      o = Observation.make!( taxon: tn.taxon )
      get :show, format: :json, params: { id: o.id }
      response_obs = JSON.parse( response.body )
      expect( response_obs["identifications"].first["taxon"]["common_name"]["name"] ).not_to be_blank
    end

    it "should include taxon rank level" do
      o = Observation.make!( taxon: Taxon.make!( :species ) )
      get :show, format: :json, params: { id: o.id }
      r = JSON.parse( response.body )
      expect( r["taxon"]["rank_level"] ).to eq Taxon::SPECIES_LEVEL
    end

    it "should include user name" do
      o = Observation.make!
      get :show, format: :json, params: { id: o.id }
      r = JSON.parse( response.body )
      expect( r["user"]["name"] ).to eq o.user.name
    end

    describe "faves" do
      let( :o ) { Observation.make! }
      let( :voter ) { User.make! }
      before do
        o.vote_by voter: voter, vote: true
      end
      it "should be included" do
        get :show, format: :json, params: { id: o.id }
        r = JSON.parse( response.body )
        expect( r["faves"] ).not_to be_blank
      end
      it "should have users with id, login, and icon" do
        get :show, format: :json, params: { id: o.id }
        r = JSON.parse( response.body )
        user = r["faves"][0]["user"]
        expect( user["login"] ).to eq voter.login
        expect( user["id"] ).to eq voter.id
        expect( user["user_icon_url"] ).to eq voter.user_icon_url
      end
    end

    it "captive_flag should match observer's vote if true" do
      o = Observation.make!( user: user, captive_flag: true )
      expect( o ).to be_captive
      get :show, format: :json, params: { id: o.id }
      r = JSON.parse( response.body )
      expect( r["captive_flag"] ).to eq true
    end

    it "captive_flag should match observer's vote if false" do
      o = Observation.make!( user: user, captive_flag: false )
      expect( o ).not_to be_captive
      get :show, format: :json, params: { id: o.id }
      r = JSON.parse( response.body )
      expect( r["captive_flag"] ).to eq false
    end

    it "captive_flag should be false if observer hasn't voted" do
      o = Observation.make!( user: user )
      get :show, format: :json, params: { id: o.id }
      r = JSON.parse( response.body )
      expect( r["captive_flag"] ).to eq false
    end

    it "should include project observations with project descriptions" do
      po = ProjectObservation.make!
      get :show, format: :json, params: { id: po.observation_id }
      r = JSON.parse( response.body )
      expect( r["project_observations"] ).not_to be_blank
      expect( r["project_observations"][0]["project"]["description"] ).to eq po.project.description
    end
  end

  describe "update" do
    let( :o ) { Observation.make!( user: user ) }

    it "should accept nested observation_field_values" do
      of = ObservationField.make!
      put :update, format: :json, params: { id: o.id, observation: {
        observation_field_values_attributes: {
          "0" => {
            observation_field_id: of.id,
            value: "foo"
          }
        }
      } }
      expect( response ).to be_successful
      o.reload
      expect( o.observation_field_values.last.observation_field ).to eq of
      expect( o.observation_field_values.last.value ).to eq "foo"
    end

    it "should update existing observation_field_values" do
      ofv = ObservationFieldValue.make!( value: "foo", observation: o )
      put :update, format: :json, params: { id: ofv.observation_id, observation: {
        observation_field_values_attributes: {
          "0" => {
            id: ofv.id,
            observation_field_id: ofv.observation_field_id,
            value: "bar"
          }
        }
      } }
      expect( response ).to be_successful
      ofv.reload
      expect( ofv.value ).to eq "bar"
    end

    it "should update existing observation_field_values by observation_field_id" do
      ofv = ObservationFieldValue.make!( value: "foo", observation: o )
      put :update, format: :json, params: { id: ofv.observation_id, observation: {
        observation_field_values_attributes: {
          "0" => {
            observation_field_id: ofv.observation_field_id,
            value: "bar"
          }
        }
      } }
      expect( response ).to be_successful
      ofv.reload
      expect( ofv.value ).to eq "bar"
    end

    it "should update existing observation_field_values by observation_field_id even if they're project fields" do
      pof = ProjectObservationField.make!
      po = make_project_observation( project: pof.project, user: user )
      ofv = ObservationFieldValue.make!(
        value: "foo",
        observation: po.observation,
        observation_field: pof.observation_field
      )
      put :update, format: :json, params: { id: ofv.observation_id, observation: {
        observation_field_values_attributes: {
          "0" => {
            observation_field_id: ofv.observation_field_id,
            value: "bar"
          }
        }
      } }
      expect( response ).to be_successful
      ofv.reload
      expect( ofv.value ).to eq "bar"
    end

    it "should allow removal of nested observation_field_values" do
      ofv = ObservationFieldValue.make!( value: "foo", observation: o )
      expect( o.observation_field_values ).not_to be_blank
      put :update, format: :json, params: { id: ofv.observation_id, observation: {
        observation_field_values_attributes: {
          "0" => {
            _destroy: true,
            id: ofv.id,
            observation_field_id: ofv.observation_field_id,
            value: ofv.value
          }
        }
      } }
      expect( response ).to be_successful
      o.reload
      expect( o.observation_field_values ).to be_blank
    end

    it "should respond with 410 for deleted observations" do
      oid = o.id
      o.destroy
      put :update, format: :json, params: { id: oid, observation: { description: "this is different" } }
      expect( response.status ).to eq 410
    end

    it "should assume request lat/lon are the true coordinates" do
      o = make_observation_of_threatened( user: user )
      lat = o.latitude
      lon = o.longitude
      plat = o.private_latitude
      plon = o.private_longitude
      expect( lat ).not_to eq plat
      expect( lon ).not_to eq plon
      put :update, format: :json, params: { id: o.id, observations: [{ latitude: plat, longitude: plon }] }
      o.reload
      expect( o.private_latitude ).to eq plat
    end

    it "should change coordinates and geoprivacy in a single request" do
      o = create :observation, user: user, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED
      put :update, format: :json, params: {
        id: o.id,
        observation: {
          latitude: 2,
          longitude: 2,
          geoprivacy: Observation::OPEN
        }
      }
      o.reload
      expect( o.private_latitude ).to be_blank
      expect( o.geoprivacy ).to be_blank
      expect( o.latitude ).to eq 2
    end

    it "should not change the true coordinates when switching to a threatened taxon and back" do
      normal = Taxon.make!
      threatened = make_threatened_taxon
      o = Observation.make!( user: user, taxon: normal, latitude: 1, longitude: 1 )
      expect( o.latitude.to_f ).to eq 1.0
      put :update, format: :json, params: { id: o.id, observation: { taxon_id: threatened.id } }
      o.reload
      expect( o.private_latitude ).not_to be_blank
      expect( o.private_latitude ).not_to eq o.latitude
      expect( o.private_latitude.to_f ).to eq 1.0
      put :update, format: :json, params: { id: o.id, observation: { taxon_id: normal.id } }
      o.reload
      expect( o.private_latitude ).to be_blank
      expect( o.latitude.to_f ).to eq 1.0
    end

    it "should deal with updating the taxon_id" do
      t1 = Taxon.make!
      t2 = Taxon.make!
      t3 = Taxon.make!
      o = Observation.make!( taxon: t1, user: user )
      o.update( taxon: t2, editing_user_id: o.user_id )
      o.reload
      expect( o.identifications.count ).to eq 2
      put :update, format: :json, params: { id: o.id, observation: { taxon_id: t3.id } }
      o.reload
      expect( o.identifications.count ).to eq 3
    end

    it "should remove the taxon when taxon_id is blank" do
      o = Observation.make!( user: user, taxon: Taxon.make! )
      expect( o.taxon ).not_to be_blank
      put :update, format: :json, params: { id: o.id, observation: { taxon_id: nil } }
      o.reload
      expect( o.taxon ).to be_blank
    end

    it "should mark as captive in response to captive_flag" do
      o = Observation.make!( user: user )
      expect( o ).not_to be_captive_cultivated
      put :update, format: :json, params: { id: o.id, observation: { captive_flag: "1" } }
      o.reload
      expect( o ).to be_captive_cultivated
    end

    it "should not mark as wild in response to captive_flag=0 if there is no existing quality metric" do
      o = Observation.make!( user: user )
      expect( o ).not_to be_captive_cultivated
      put :update, format: :json, params: { id: o.id, observation: { captive_flag: "0" } }
      o.reload
      qm = o.quality_metrics.where( metric: QualityMetric::WILD ).first
      expect( qm ).to be_blank
    end

    it "should mark as wild in response to captive_flag=0 if there is an existing quality metric" do
      o = Observation.make!( user: user, captive_flag: true )
      expect( o ).to be_captive_cultivated
      put :update, format: :json, params: { id: o.id, observation: { captive_flag: "0" } }
      o.reload
      qm = o.quality_metrics.where( metric: QualityMetric::WILD ).first
      expect( qm ).to be_agree
    end

    it "should remove place_guess when changing geoprivacy to private" do
      original_place_guess = "foo"
      o = Observation.make!( user: user, place_guess: original_place_guess, latitude: 1, longitude: 1 )
      expect( o.place_guess ).to eq original_place_guess
      put :update, format: :json, params: { id: o.id, observation: { geoprivacy: Observation::PRIVATE } }
      o.reload
      expect( o.place_guess ).to be_blank
    end

    it "should return private coordinates if geoprivacy is private" do
      o = Observation.make!( user: user, latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE )
      put :update, format: :json, params: { id: o.id, observation: { description: "foo" } }
      json = JSON.parse( response.body )[0]
      expect( json["private_latitude"] ).not_to be_blank
    end

    it "should return private coordinates if geoprivacy is obscured" do
      o = Observation.make!( user: user, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED )
      put :update, format: :json, params: { id: o.id, observation: { description: "foo" } }
      json = JSON.parse( response.body )[0]
      expect( json["private_latitude"] ).not_to be_blank
    end

    describe "private_place_guess" do
      let( :p ) { make_place_with_geom( admin_level: Place::COUNTRY_LEVEL, name: "Freedonia" ) }
      let( :original_place_guess ) { "super secret place" }
      let( :o ) do
        Observation.make!(
          latitude: p.latitude,
          longitude: p.longitude,
          geoprivacy: Observation::OBSCURED,
          place_guess: original_place_guess,
          user: user
        )
      end
      it "should not change if the obscured place_guess is submitted" do
        obscured_place_guess = o.place_guess
        expect( obscured_place_guess ).to eq p.name
        put :update, format: :json, params: {
          id: o.id, observation: { place_guess: original_place_guess, description: "foo" }
        }
        o.reload
        expect( o.description ).to eq "foo"
        expect( o ).to be_coordinates_obscured
        expect( o.place_guess ).to eq obscured_place_guess
        expect( o.private_place_guess ).to eq original_place_guess
      end
      it "should change with a new place_guess" do
        obscured_place_guess = o.place_guess
        new_place_guess = "a totally different place"
        put :update, format: :json, params: { id: o.id, observation: { place_guess: new_place_guess } }
        o.reload
        expect( o.place_guess ).to eq obscured_place_guess
        expect( o.private_place_guess ).to eq new_place_guess
      end
      it "should not change when updating an observation of a threatened taxon" do
        o = Observation.make!(
          taxon: make_threatened_taxon,
          latitude: 1,
          longitude: 1,
          place_guess: original_place_guess,
          user: user
        )
        expect( o.private_place_guess ).to eq original_place_guess
        put :update, format: :json, params: { id: o.id, observation: { description: "foo" } }
        o.reload
        expect( o.private_place_guess ).to eq original_place_guess
      end
    end

    describe "existing photos" do
      let( :o ) { make_research_grade_observation( user: user ) }
      it "should be left alone if included" do
        op = o.observation_photos.first
        put :update, format: :json, params: {
          id: o.id,
          local_photos: {
            o.id.to_s => [o.photos.first.id]
          },
          observation: { description: "foo" }
        }
        Delayed::Worker.new.work_off
        o.reload
        expect( o.photos ).not_to be_blank
        reloaded_op = ObservationPhoto.find_by_id( op.id )
        expect( reloaded_op ).not_to be_blank
        expect( reloaded_op.photo_id ).to eq op.photo_id
        expect( reloaded_op.photo ).not_to be_blank
      end
      it "should be left alone if included with a new photo" do
        op = o.observation_photos.first
        new_p = LocalPhoto.make!( user: o.user )
        put :update, format: :json, params: {
          id: o.id,
          local_photos: {
            o.id.to_s => [o.photos.first.id, new_p.id]
          },
          observation: { description: "foo" }
        }
        Delayed::Worker.new.work_off
        o.reload
        expect( o.photos.size ).to eq 2
        reloaded_op = ObservationPhoto.find_by_id( op.id )
        expect( reloaded_op ).not_to be_blank
        expect( reloaded_op.photo_id ).to eq op.photo_id
        expect( reloaded_op.photo ).not_to be_blank
      end
      describe "if omitted" do
        it "should be deleted" do
          op = o.observation_photos.first
          put :update, format: :json, params: { id: o.id, observation: { description: "foo" } }
          Delayed::Worker.new.work_off
          o.reload
          expect( o.photos ).to be_blank
          expect( ObservationPhoto.find_by_id( op.id ) ).to be_blank
        end
        it "should delete corresponding ObservationPhotos" do
          without_delay { put :update, format: :json, params: { id: o.id, observation: { description: "foo" } } }
          o.reload
          expect( o.observation_photos ).to be_blank
        end
        it "should not be deleted if they are not orphaned, but ObservationPhotos should" do
          other_o = Observation.make!( user: o.user )
          other_op = ObservationPhoto.make!( observation: other_o, photo: o.photos.first )
          put :update, format: :json, params: { id: o.id, observation: { description: "foo" } }
          Delayed::Worker.new.work_off
          reloaded_other_op = other_op.reload
          expect( reloaded_other_op.photo ).not_to be_blank
          expect( Photo.find_by_id( other_op.photo_id ) ).not_to be_blank
        end
      end
    end

    describe "with owners_identification_from_vision" do
      let( :observation ) { Observation.make!( user: user, taxon: Taxon.make! ) }
      it "should update if requested and taxon changed" do
        expect( observation.owners_identification_from_vision ).to be false
        put :update, format: :json, params: { id: observation.id, observation: {
          owners_identification_from_vision: true,
          taxon_id: Taxon.make!.id
        } }
        json = JSON.parse( response.body )[0]
        expect( json["owners_identification_from_vision"] ).to be true
        observation.reload
        expect( observation.owners_identification_from_vision ).to be true
      end
      it "should not update if requested and taxon did not changed" do
        put :update, format: :json, params: { id: observation.id, observation: {
          owners_identification_from_vision: true,
          description: "this shouldn't update b/c the taxon didn't change so no ID was made"
        } }
        json = JSON.parse( response.body )[0]
        expect( json["owners_identification_from_vision"] ).to be false
        observation.reload
        expect( observation.owners_identification_from_vision ).to be false
      end
      it "should set the vision attribute on the corresponding identification if changed and taxon changed" do
        old_owners_ident = observation.owners_identification
        put :update, format: :json, params: { id: observation.id, observation: {
          owners_identification_from_vision: true,
          taxon_id: Taxon.make!.id
        } }
        observation.reload
        new_owners_ident = observation.owners_identification
        expect( new_owners_ident.id ).not_to eq old_owners_ident.id
        expect( new_owners_ident.vision ).to be true
      end
    end

    it "should not change the private coordinates if user geoprivacy is opened but taxon geoprivacy is obscured" do
      t = make_threatened_taxon
      o = Observation.make!( user: user, geoprivacy: Observation::OBSCURED, taxon: t, latitude: 1, longitude: 1 )
      o.reload
      expect( o ).to be_coordinates_obscured
      put :update, format: :json, params: {
        id: o.id,
        observation: {
          geoprivacy: "",
          latitude: o.private_latitude,
          longitude: o.private_longitude
        }
      }
      o.reload
      expect( o.geoprivacy ).not_to eq Observation::OBSCURED
      expect( o ).to be_coordinates_obscured
      expect( o.latitude ).not_to eq o.private_latitude
    end

    describe "changing geoprivacy from private to obscured" do
      let( :obs ) { Observation.make!( user: user, latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE ) }
      def update_to_obscured( obs )
        put :update, format: :json, params: {
          id: obs.id,
          observation: {
            geoprivacy: Observation::OBSCURED,
            latitude: obs.private_latitude,
            longitude: obs.private_longitude
          }
        }
        obs.reload
      end
      it "should set latitude" do
        expect( obs.latitude ).to be_blank
        update_to_obscured( obs )
        expect( obs.geoprivacy ).to eq Observation::OBSCURED
        expect( obs.latitude ).not_to be_blank
      end
      it "should not change the private coordinates" do
        private_latitude = obs.private_latitude
        update_to_obscured( obs )
        expect( obs.private_latitude ).to eq private_latitude
      end
      it "should not reveal the private coordinates" do
        put :update, format: :json, params: { id: obs.id, observation: { geoprivacy: Observation::OBSCURED } }
        update_to_obscured( obs )
        expect( obs.latitude ).not_to eq obs.private_latitude
      end
      it "should not reveal the private coordinates when updating with the private coordinates" do
        put :update, format: :json, params: { id: obs.id, observation: {
          geoprivacy: Observation::OBSCURED,
          latitude: obs.private_latitude,
          longitude: obs.private_longitude
        } }
        update_to_obscured( obs )
        expect( obs.latitude ).not_to eq obs.private_latitude
      end
    end

    it "should not allow observations where latitude AND longitude are 0" do
      o = Observation.make!( user: user )
      put :update, params: { id: o.id, format: :json, observation: { latitude: 0, longitude: 0 } }
      expect( response.status ).to eq 422
      o.reload
      expect( o.latitude ).not_to eq 0
    end

    it "should not allow alteration of created_at" do
      o = Observation.make!( user: user, created_at: 3.weeks.ago )
      expect( o.created_at ).to be <= 2.week.ago
      put :update, params: { id: o.id, format: :json, observation: { created_at: 1.week.ago.iso8601 } }
      o.reload
      expect( o.created_at ).to be <= 2.week.ago
    end

    it "should allow coordinate removal when obscured" do
      o = Observation.make!( user: user, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED )
      put :update, params: { id: o.id, format: :json, observation: { latitude: "", longitude: "" } }
      expect( response ).to be_successful
      o.reload
      expect( o.latitude ).to be_blank
      expect( o.private_latitude ).to be_blank
      expect( o ).not_to be_georeferenced
    end

    it "should update the license by license_code" do
      expect( o.license ).to eq Observation::CC_BY
      put :update, params: { id: o.id, format: :json, observation: { license_code: "cc0" } }
      o.reload
      expect( o.license ).to eq Observation::CC0
    end

    it "should remove the license if license_code is a blank string" do
      expect( o.license ).to eq Observation::CC_BY
      put :update, params: { id: o.id, format: :json, observation: { license_code: "" } }
      o.reload
      expect( o.license ).to be_blank
    end

    it "should not remove the license if license_code is not specified" do
      expect( o.license ).to eq Observation::CC_BY
      put :update, params: { id: o.id, format: :json, observation: { description: "foo" } }
      o.reload
      expect( o.license ).to eq Observation::CC_BY
    end

    describe "time_zone" do
      before(:all) { load_time_zone_geometries }
      after(:all) { unload_time_zone_geometries }

      it "should not change the time zone if the coordinates don't change" do
        o.update( latitude: 20, longitude: 20 )
        expect( o ).to be_georeferenced
        expect( o.zic_time_zone ).not_to eq "America/Los_Angeles"
        original_time_zone = expect( o.time_zone )
        put :update, params: { id: o.id, format: :json, observation: { time_zone: "America/Los_Angeles" } }
        o.reload
        expect( o.zic_time_zone ).not_to eq "America/Los_Angeles"
      end
    end
  end

  describe "by_login" do
    elastic_models( Observation )

    it "should get user's observations" do
      3.times { Observation.make!( user: user ) }
      get :by_login, format: :json, params: { login: user.login }
      json = JSON.parse( response.body )
      expect( json.size ).to eq( 3 )
    end

    it "should allow filtering by updated_since" do
      oldo = Observation.make!( created_at: 1.day.ago, updated_at: 1.day.ago, user: user )
      expect( oldo.updated_at ).to be < 1.minute.ago
      newo = Observation.make!( user: user )
      get :by_login, format: :json, params: { login: user.login, updated_since: ( newo.updated_at - 1.minute ).iso8601 }
      json = JSON.parse( response.body )
      expect( json.detect {| o | o["id"] == newo.id } ).not_to be_blank
      expect( json.detect {| o | o["id"] == oldo.id } ).to be_blank
    end

    it "should allow filtering by updated_since with positive offsets" do
      time_zone_was = Time.zone
      Time.zone = ActiveSupport::TimeZone["Berlin"]
      oldo = Observation.make!( created_at: 10.days.ago, updated_at: 5.days.ago, user: user )
      newo = Observation.make!( user: user )
      updated_stamp = ( newo.updated_at - 4.days ).iso8601
      expect( updated_stamp ).to match( /\+\d\d:\d\d$/ )
      get :by_login, format: :json, params: { login: user.login, updated_since: updated_stamp }
      json = JSON.parse( response.body )
      expect( json.detect {| o | o["id"] == newo.id } ).not_to be_blank
      expect( json.detect {| o | o["id"] == oldo.id } ).to be_blank
      Time.zone = time_zone_was
    end

    it "should return no results if updated_since is specified but incorrectly formatted" do
      oldo = Observation.make!( created_at: 1.day.ago, updated_at: 1.day.ago, user: user )
      expect( oldo.updated_at ).to be < 1.minute.ago
      newo = Observation.make!( user: user )
      stamp = ( newo.updated_at - 1.minute ).iso8601
      bad_stamp = stamp.gsub( /:/, "-" )
      get :by_login, format: :json, params: { login: user.login, updated_since: bad_stamp }
      json = JSON.parse( response.body )
      expect( json ).to be_blank
    end

    it "should include deleted observation IDs when filtering by updated_since" do
      oldo = Observation.make!( created_at: 1.day.ago, updated_at: 1.day.ago )
      expect( oldo.updated_at ).to be < 1.minute.ago
      delo1 = Observation.make!( user: user )
      delo1.destroy
      delo2 = Observation.make!( user: user )
      delo2.destroy
      get :by_login, format: :json, params: { login: user.login, updated_since: 2.days.ago.iso8601 }
      expect( response.headers["X-Deleted-Observations"].split( "," ) ).to include( delo1.id.to_s )
      expect( response.headers["X-Deleted-Observations"].split( "," ) ).to include( delo2.id.to_s )
    end

    it "should not include deleted observation IDs by other people" do
      oldo = Observation.make!( created_at: 1.day.ago, updated_at: 1.day.ago )
      expect( oldo.updated_at ).to be < 1.minute.ago
      delo1 = Observation.make!( user: user )
      delo1.destroy
      delo2 = Observation.make!
      delo2.destroy
      get :by_login, format: :json, params: { login: user.login, updated_since: 2.days.ago.iso8601 }
      expect( response.headers["X-Deleted-Observations"].split( "," ) ).to include( delo1.id.to_s )
      expect( response.headers["X-Deleted-Observations"].split( "," ) ).not_to include( delo2.id.to_s )
    end

    it "should return private observations for bounding box queries when viewer is owner" do
      o = Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE, user: user )
      expect( o.private_geom ).not_to be_blank
      get :by_login, format: :json, params: { login: user.login, swlat: 0, swlng: 0, nelat: 2, nelng: 2 }
      json = JSON.parse( response.body )
      expect( json.map {| jo | jo["id"] } ).to include o.id
    end

    it "should include private coordinates when viewer is owner" do
      o = Observation.make!( latitude: 1.2345, longitude: 1.2345, geoprivacy: Observation::PRIVATE, user: user )
      expect( o.private_geom ).not_to be_blank
      get :by_login, format: :json, params: { login: user.login, swlat: 0, swlng: 0, nelat: 2, nelng: 2 }
      json = JSON.parse( response.body )
      json_obs = json.detect {| jo | jo["id"] == o.id }
      expect( json_obs ).not_to be_blank
      expect( json_obs["private_latitude"] ).to eq o.private_latitude.to_s
    end

    it "should return names specific to the user's place" do
      t = Taxon.make!( rank: Taxon::SPECIES )
      TaxonName.make!( taxon: t, lexicon: TaxonName::ENGLISH )
      tn_place = TaxonName.make!( taxon: t, lexicon: TaxonName::ENGLISH )
      ptn = PlaceTaxonName.make!( taxon_name: tn_place )
      user.update( place_id: ptn.place_id )
      o = Observation.make!( user: user, taxon: t )
      get :by_login, format: :json, params: { login: user.login, taxon_id: t.id }
      json = JSON.parse( response.body )
      json_obs = json.detect {| jo | jo["id"] == o.id }
      expect( json_obs["taxon"]["common_name"]["name"] ).to eq tn_place.name
    end
  end

  describe "index" do
    elastic_models( Observation, Place, Taxon )

    it "should allow search" do
      expect do
        get :index, format: :json, params: { q: "foo" }
      end.not_to raise_error
    end

    it "should allow sorting with different cases" do
      Observation.make!
      get :index, format: :json, params: { sort: "ASC" }
      expect( JSON.parse( response.body ).length ).to eq 1
      get :index, format: :json, params: { sort: "asc" }
      expect( JSON.parse( response.body ).length ).to eq 1
      get :index, format: :json, params: { sort: "DeSC" }
      expect( JSON.parse( response.body ).length ).to eq 1
    end

    it "should filter by hour range" do
      o = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      expect( o.time_observed_at ).not_to be_blank
      get :index, format: :json, params: { h1: 13, h2: 14 }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o.id } ).not_to be_blank
    end

    it "should filter by date range" do
      o = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      expect( o.time_observed_at ).not_to be_blank
      get :index, format: :json, params: { d1: "2011-12-31", d2: "2012-01-04" }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o.id } ).not_to be_blank
    end

    it "should filter by time range" do
      o1 = Observation.make!( observed_on_string: "2014-03-28T18:57:41+00:00" )
      o2 = Observation.make!( observed_on_string: "2014-03-28T08:57:41+00:00" )
      get :index, format: :json, params: { d1: "2014-03-28T12:57:41+00:00", d2: "2014-03-28T22:57:41+00:00" }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).to be_blank
    end

    it "should filter by month range" do
      o1 = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      o2 = Observation.make!( observed_on_string: "2010-03-01 13:13" )
      get :index, format: :json, params: { m1: 11, m2: 3 }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).not_to be_blank
    end

    it "should filter by single login in user_id" do
      o1 = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      o2 = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      get :index, format: :json, params: { on: "2012-01-01", user_id: o1.user.login }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).to be_blank
    end

    it "should filter by multiple logins in user_id" do
      o1 = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      o2 = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      o3 = Observation.make!( observed_on_string: "2012-01-01 13:13" )
      get :index, format: :json, params: { on: "2012-01-01", user_id: "#{o1.user.login},#{o2.user.login}" }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o3.id } ).to be_blank
    end

    it "should filter by week of the year" do
      o1 = Observation.make!( observed_on_string: "2012-01-05T13:13+00:00" )
      o2 = Observation.make!( observed_on_string: "2010-03-01T13:13+00:00" )
      get :index, format: :json, params: { week: 1 }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).to be_blank
    end

    it "should filter by multiple months" do
      o1 = Observation.make!( observed_on_string: "2010-03-15" )
      o2 = Observation.make!( observed_on_string: "2010-04-15" )
      get :index, format: :json, params: { month: [3, 4] }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).not_to be_blank
    end

    it "should filter by captive=true" do
      captive = Observation.make!( captive_flag: "1" )
      wild = Observation.make!( captive_flag: "0" )
      get :index, format: :json, params: { captive: true }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == wild.id } ).to be_blank
      expect( json.detect {| obs | obs["id"] == captive.id } ).not_to be_blank
    end

    it "should filter by captive=false" do
      captive = Observation.make!( captive_flag: "1" )
      wild = Observation.make!( captive_flag: "0" )
      get :index, format: :json, params: { captive: false }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == captive.id } ).to be_blank
      expect( json.detect {| obs | obs["id"] == wild.id } ).not_to be_blank
    end

    it "should filter by captive when quality metrics used" do
      captive = Observation.make!
      QualityMetric.make!( observation: captive, metric: QualityMetric::WILD, agree: false )
      wild = Observation.make!
      QualityMetric.make!( observation: wild, metric: QualityMetric::WILD, agree: true )
      get :index, format: :json, params: { captive: true }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == wild.id } ).to be_blank
      expect( json.detect {| obs | obs["id"] == captive.id } ).not_to be_blank
    end

    it "captive filter=false should include nil" do
      o = Observation.make!
      get :index, format: :json, params: { captive: false }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o.id } ).not_to be_blank
    end

    it "should include pagination data in headers" do
      3.times { Observation.make! }
      total_entries = Observation.count
      get :index, format: :json, params: { page: 2, per_page: 30 }
      expect( response.headers["X-Total-Entries"].to_i ).to eq( total_entries )
      expect( response.headers["X-Page"].to_i ).to eq( 2 )
      expect( response.headers["X-Per-Page"].to_i ).to eq( 30 )
    end

    it "should paginate" do
      5.times { Observation.make! }
      total_entries = Observation.count
      get :index, format: :json, params: { page: 1, per_page: 2 }
      expect( response.headers["X-Total-Entries"].to_i ).to eq( total_entries )
      expect( response.headers["X-Page"].to_i ).to eq( 1 )
      expect( response.headers["X-Per-Page"].to_i ).to eq( 2 )
      expect( JSON.parse( response.body ).length ).to eq( 2 )
    end

    it "should filter by min_id" do
      o1 = Observation.make!
      o2 = Observation.make!
      o3 = Observation.make!
      expect( o1.id ).to be < o2.id
      expect( o2.id ).to be < o3.id
      get :index, format: :json, params: { min_id: o2.id }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o3.id } ).not_to be_blank
    end

    it "should filter by min_id and per_page" do
      o1 = Observation.make!
      o2 = Observation.make!
      o3 = Observation.make!
      Observation.make!
      expect( o1.id ).to be < o2.id
      expect( o2.id ).to be < o3.id
      get :index, format: :json, params: { min_id: o2.id, per_page: 2, order_by: "created_at", order: "asc" }
      json = JSON.parse( response.body )
      obs_ids = json.map {| o | o["id"] }
      expect( obs_ids.size ).to eq 2
      expect( obs_ids ).not_to include o1.id
      expect( obs_ids ).to include o2.id
    end

    it "should not include photo metadata" do
      p = LocalPhoto.make!( )
      pm = PhotoMetadata.make!( photo: p, metadata: { foo: "bar" } )
      expect( p.metadata ).not_to be_blank
      o = Observation.make!( user: p.user, taxon: Taxon.make! )
      make_observation_photo( photo: p, observation: o )
      get :index, format: :json, params: { taxon_id: o.taxon_id }
      json = JSON.parse( response.body )
      response_obs = json.detect {| obs | obs["id"] == o.id }
      expect( response_obs ).not_to be_blank
      response_photo = response_obs["photos"].first
      expect( response_photo ).not_to be_blank
      expect( response_photo["metadata"] ).to be_blank
    end

    it "should filter by conservation_status" do
      cs = without_delay { ConservationStatus.make! }
      t = cs.taxon
      o1 = Observation.make!( taxon: t )
      o2 = Observation.make!( taxon: Taxon.make! )
      get :index, format: :json, params: { cs: cs.status }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).to be_blank
    end

    it "should filter by conservation_status authority" do
      cs1 = without_delay { ConservationStatus.make!( authority: "foo" ) }
      cs2 = without_delay { ConservationStatus.make!( authority: "bar", status: cs1.status ) }
      o1 = Observation.make!( taxon: cs1.taxon )
      o2 = Observation.make!( taxon: cs2.taxon )
      get :index, format: :json, params: { csa: cs1.authority }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).to be_blank
    end

    it "should filter by establishment means" do
      p = make_place_with_geom
      Delayed::Worker.new.work_off
      lt1 = ListedTaxon.make!( establishment_means: ListedTaxon::INTRODUCED, list: p.check_list, place: p )
      lt2 = ListedTaxon.make!( establishment_means: ListedTaxon::NATIVE, list: p.check_list, place: p )
      Delayed::Worker.new.work_off
      o1 = Observation.make!( taxon: lt1.taxon, latitude: p.latitude, longitude: p.longitude )
      o2 = Observation.make!( taxon: lt2.taxon, latitude: p.latitude, longitude: p.longitude )
      get :index, format: :json, params: { introduced: true, place_id: p.id }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == o2.id } ).to be_blank
    end

    describe "filtration by tag in elasticsearch" do
      after do
        tagged = Observation.make!( tag_list: @tag )
        Observation.make!
        get :index, format: :json, params: { q: @tag, search_on: "tags" }
        json = JSON.parse( response.body )
        expect( json.size ).to eq 1
        expect( json.detect {| obs | obs["id"] == tagged.id } ).not_to be_blank
      end
      it "should work" do
        @tag = "thetag"
      end
      it "with hyphen" do
        @tag = "the-tag"
      end
      it "with colon" do
        @tag = "the:tag"
      end
      it "with underscore" do
        @tag = "the_tag"
      end
    end

    it "should filter by tag with an underscore in the database" do
      list = List.make!
      taxon = Taxon.make!
      list.add_taxon( taxon )
      o = Observation.make!( tag_list: @tag, taxon: taxon )
      Observation.make!
      # filtering by list_id should force a database search
      get :index, format: :json, params: { q: @tag, search_on: "tags", list_id: list.id }
      json = JSON.parse( response.body )
      expect( json.size ).to eq 1
      expect( json.detect {| obs | obs["id"] == o.id } ).not_to be_blank
    end

    it "should include common names" do
      tn = TaxonName.make!( lexicon: TaxonName::ENGLISH )
      Observation.make!( taxon: tn.taxon )
      get :index, format: :json, params: { taxon_id: tn.taxon_id }
      json = JSON.parse( response.body )
      jsono = json.first
      expect( jsono["taxon"]["common_name"]["name"] ).to eq tn.name
    end

    describe "identifications_count" do
      it "should get incremented" do
        o = Observation.make!
        i = Identification.make!( observation: o )
        get :index, format: :json
        obs = JSON.parse( response.body ).detect {| jo | jo["id"] == i.observation_id }
        expect( obs["identifications_count"] ).to eq 1
      end
    end

    it "should include comments_count" do
      c = Comment.make!
      get :index, format: :json
      obs = JSON.parse( response.body ).detect {| o | o["id"] == c.parent_id }
      expect( obs["comments_count"] ).to eq 1
    end

    it "should include faves_count" do
      o = Observation.make!
      o.liked_by User.make!
      get :index, format: :json
      obs = JSON.parse( response.body ).detect {| r | r["id"] == o.id }
      expect( obs["faves_count"] ).to eq 1
    end

    it "should let you request project_observations as extra data" do
      po = make_project_observation
      get :index, format: :json, params: { extra: "projects" }
      obs = JSON.parse( response.body ).detect {| o | o["id"] == po.observation_id }
      expect( obs["project_observations"] ).not_to be_blank
    end

    it "should let you request observation field values as extra data" do
      ofv = ObservationFieldValue.make!
      get :index, format: :json, params: { extra: "fields" }
      obs = JSON.parse( response.body ).detect {| o | o["id"] == ofv.observation_id }
      expect( obs["observation_field_values"] ).not_to be_blank
    end

    it "should let you request observation_photos as extra data" do
      rgo = make_research_grade_observation
      get :index, format: :json, params: { extra: "observation_photos" }
      obs = JSON.parse( response.body ).detect {| o | o["id"] == rgo.id }
      expect( obs["observation_photos"] ).not_to be_nil
    end

    it "should let you request identifications as extra data" do
      rgo = make_research_grade_observation
      get :index, format: :json, params: { extra: "identifications" }
      obs = JSON.parse( response.body ).detect {| o | o["id"] == rgo.id }
      expect( obs["identifications"] ).not_to be_nil
    end

    it "should filter by list_id" do
      l = List.make!
      lt = ListedTaxon.make!( list: l )
      on_list_obs = Observation.make!( observed_on_string: "2013-01-03", taxon: lt.taxon )
      off_list_obs = Observation.make!( observed_on_string: "2013-01-03", taxon: Taxon.make! )
      get :index, format: :json, params: { on: on_list_obs.observed_on_string, list_id: l.id }
      json_obs = JSON.parse( response.body )
      expect( json_obs.detect {| o | o["id"] == on_list_obs.id } ).not_to be_blank
      expect( json_obs.detect {| o | o["id"] == off_list_obs.id } ).to be_blank
    end

    it "should not require sign in for page 100 or more" do
      get :index, format: :json, params: { page: 101 }
      expect( response ).to be_successful
    end

    it "should filter by taxon name" do
      o1 = Observation.make!( taxon: Taxon.make! )
      Observation.make!( taxon: Taxon.make! )
      get :index, format: :json, params: { taxon_name: o1.taxon.name }
      expect( JSON.parse( response.body ).size ).to eq 1
    end

    it "should filter by taxon name regardless of case" do
      t = Taxon.make!( name: "Foo bar" )
      Observation.make!( taxon: t )
      Observation.make!( taxon: Taxon.make! )
      get :index, format: :json, params: { taxon_name: "foo bar" }
      expect( JSON.parse( response.body ).size ).to eq 1
    end

    it "should filter by taxon name if there are synonyms and iconic_taxa provided" do
      load_test_taxa
      o1 = Observation.make!( taxon: @Pseudacris_regilla )
      synonym = Taxon.make!( parent: @Calypte, name: o1.taxon.name, rank: Taxon::SPECIES )
      Observation.make!( taxon: synonym )
      get :index, format: :json, params: { taxon_name: o1.taxon.name, iconic_taxa: [@Aves.name] }
      expect( JSON.parse( response.body ).size ).to eq 1
    end

    it "should filter by multiple taxon ids" do
      load_test_taxa
      o1 = Observation.make!( taxon: @Calypte_anna )
      o2 = Observation.make!( taxon: @Pseudacris_regilla )
      o3 = Observation.make!( taxon: Taxon.make! )
      get :index, format: :json, params: { taxon_ids: [@Aves.id, @Amphibia.id] }
      json = JSON.parse( response.body )
      expect( json.detect {| o | o["id"] == o1.id } ).not_to be_blank
      expect( json.detect {| o | o["id"] == o2.id } ).not_to be_blank
      expect( json.detect {| o | o["id"] == o3.id } ).to be_blank
    end

    it "should filter by place and multiple taxon ids" do
      load_test_taxa
      place = make_place_with_geom
      in_place_bird = Observation.make!( taxon: @Calypte_anna, latitude: place.latitude, longitude: place.longitude )
      in_place_frog = Observation.make!( taxon: @Pseudacris_regilla, latitude: place.latitude,
        longitude: place.longitude )
      in_place_other = Observation.make!( taxon: Taxon.make!, latitude: place.latitude, longitude: place.longitude )
      out_of_place_bird = Observation.make!( taxon: @Calypte_anna, latitude: place.latitude * -1,
        longitude: place.longitude * -1 )
      out_of_place_other = Observation.make!( taxon: Taxon.make!, latitude: place.latitude * -1,
        longitude: place.longitude * -1 )
      get :index, format: :json, params: { taxon_ids: [@Aves.id, @Amphibia.id], place_id: place.id }
      json = JSON.parse( response.body )
      expect( json.detect {| o | o["id"] == in_place_bird.id } ).not_to be_blank
      expect( json.detect {| o | o["id"] == in_place_frog.id } ).not_to be_blank
      expect( json.detect {| o | o["id"] == in_place_other.id } ).to be_blank
      expect( json.detect {| o | o["id"] == out_of_place_bird.id } ).to be_blank
      expect( json.detect {| o | o["id"] == out_of_place_other.id } ).to be_blank
    end

    it "should filter by mappable = true" do
      Observation.make!
      Observation.make!
      Observation.make!( latitude: 1.2, longitude: 2.2 )
      get :index, format: :json, params: { mappable: "true" }
      expect( JSON.parse( response.body ).count ).to eq 1
    end

    it "should filter by mappable = false" do
      Observation.make!
      Observation.make!
      Observation.make!( latitude: 1.2, longitude: 2.2 )
      get :index, format: :json, params: { mappable: "false" }
      expect( JSON.parse( response.body ).count ).to eq 2
    end

    it "should not filter by mappable when its nil" do
      Observation.make!
      Observation.make!
      Observation.make!( latitude: 1.2, longitude: 2.2 )
      get :index, format: :json, params: { mappable: nil }
      expect( JSON.parse( response.body ).count ).to eq 3
    end

    it "should include place_guess" do
      o = Observation.make!( place_guess: "my backyard" )
      get :index, format: :json
      expect( response.body ).to be =~ /#{o.place_guess}/
    end

    it "should not include place_guess if coordinates obscured" do
      o = Observation.make!( place_guess: "my backyard", geoprivacy: Observation::OBSCURED )
      get :index, format: :json
      expect( response.body ).to be =~ /#{o.place_guess}/
    end

    it "should filter by project slug" do
      po = make_project_observation
      get :index, format: :json, params: { projects: po.project.slug }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == po.observation_id } ).not_to be_blank
    end

    it "should filter by project slug if it begins with a number" do
      po1 = make_project_observation( project: Project.make!( title: "7eves" ) )
      po2 = make_project_observation( project: Project.make!( id: 7 ) )
      get :index, format: :json, params: { projects: po1.project.slug }
      json = JSON.parse( response.body )
      expect( json.detect {| obs | obs["id"] == po1.observation_id } ).not_to be_blank
      expect( json.detect {| obs | obs["id"] == po2.observation_id } ).to be_blank
    end

    it "should filter by observations not in a project" do
      po1 = ProjectObservation.make!
      po2 = ProjectObservation.make!
      get :index, format: :json, params: { not_in_project: po1.project_id }
      json = JSON.parse( response.body )
      expect( json.detect {| o | o["id"] == po1.observation_id } ).to be_blank
      expect( json.detect {| o | o["id"] == po2.observation_id } ).not_to be_blank
    end

    it "should filter by identified" do
      identified = Observation.make!( taxon: Taxon.make! )
      unidentified = Observation.make!
      get :index, format: :json, params: { identified: true }
      json = JSON.parse( response.body )
      expect( json.detect {| o | o["id"] == unidentified.id } ).to be_blank
      expect( json.detect {| o | o["id"] == identified.id } ).not_to be_blank
    end

    it "should filter by not identified" do
      identified = Observation.make!( taxon: Taxon.make! )
      unidentified = Observation.make!
      get :index, format: :json, params: { identified: false }
      json = JSON.parse( response.body )
      expect( json.detect {| o | o["id"] == unidentified.id } ).not_to be_blank
      expect( json.detect {| o | o["id"] == identified.id } ).to be_blank
    end

    it "should allow limit" do
      10.times { Observation.make! }
      get :index, format: :json, params: { limit: 3 }
      expect( JSON.parse( response.body ).size ).to eq 3
    end

    it "filters on observation fields" do
      o = Observation.make!
      of = ObservationField.make!( name: "transect_id" )
      ObservationFieldValue.make!( observation: o, observation_field: of, value: "67-48" )
      get :index, format: :json, params: { "field:transect_id" => "67-48" }
      expect( JSON.parse( response.body ).size ).to eq 1
    end

    it "filters created_on based on timezone in which it was created" do
      Observation.make!( created_at: "2014-12-31 20:00:00 -0800" )
      Observation.make!( created_at: "2015-1-1 4:00:00" )
      Observation.make!( created_at: "2015-1-2 4:00:00 +0800" )
      get :index, format: :json, params: { created_on: "2015-1-1" }
      expect( JSON.parse( response.body ).size ).to eq 1
    end

    it "should filter by has[]=photos" do
      with_photo = without_delay { make_research_grade_observation }
      without_photo = without_delay { Observation.make! }
      get :index, format: :json, params: { has: ["photos"] }
      obs_ids = JSON.parse( response.body ).map {| o | o["id"].to_i }
      expect( obs_ids ).to include with_photo.id
      expect( obs_ids ).not_to include without_photo.id
    end

    it "observations with no time_observed_at ignore time part of date filters" do
      Observation.make!( observed_on_string: "2014-12-31 20:00:00 -0100" )
      Observation.make!( observed_on_string: "2014-12-31" )
      get :index, format: :json, params: { d1: "2014-12-31T19:00:00-01:00", d2: "2014-12-31T21:00:00-01:00" }
      expect( JSON.parse( response.body ).size ).to eq 2
    end

    describe "filtration by pcid" do
      let( :po1 ) { ProjectObservation.make! }
      let( :p ) { po1.project }
      let( :pu ) { ProjectUser.make!( project: p, role: ProjectUser::CURATOR ) }
      let( :o1 ) { po1.observation }
      let( :i ) { Identification.make!( observation: o1, user: pu.user ) }
      let( :po2 ) { ProjectObservation.make!( project: p ) }
      let( :o2 ) { po2.observation }
      before do
        [o1, i, o2].each do | r |
          expect( r.id ).not_to be_blank
        end
        Delayed::Worker.new( quiet: true ).work_off
        [o1, o2].map( &:reload )
        [o1, o2].map( &:elastic_index! )
      end
      it "should filter by yes" do
        expect( Observation.count ).to eq 2
        get :index, format: :json, params: { pcid: "yes" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).to include o1.id
        expect( ids ).not_to include o2.id
      end
      it "should filter by no" do
        get :index, format: :json, params: { pcid: "no" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).not_to include o1.id
        expect( ids ).to include o2.id
      end
    end

    it "should sort by votes asc" do
      obs_with_votes = Observation.make!
      obs_without_votes = Observation.make!
      obs_with_votes.like_by User.make!
      expect( obs_with_votes.cached_votes_total ).to eq 1
      expect( obs_without_votes.cached_votes_total ).to eq 0
      get :index, format: :json, params: { order_by: "votes", order: "asc" }
      ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
      expect( ids.first ).to eq obs_without_votes.id
      expect( ids.last ).to eq obs_with_votes.id
    end

    it "should sort by votes asc" do
      obs_with_votes = Observation.make!
      obs_without_votes = Observation.make!
      obs_with_votes.like_by User.make!
      get :index, format: :json, params: { order_by: "votes", order: "desc" }
      ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
      expect( ids.last ).to eq obs_without_votes.id
      expect( ids.first ).to eq obs_with_votes.id
    end

    it "should sort by observed_on asc and respect time" do
      o1 = Observation.make!( observed_on_string: "2016-10-27 10am" )
      o2 = Observation.make!( observed_on_string: "2016-10-27 11am" )
      get :index, format: :json, params: { order_by: "observed_on", order: "asc" }
      ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
      expect( ids.first ).to eq o1.id
      expect( ids.last ).to eq o2.id
    end

    it "should sort by observed_on desc and respect time" do
      o1 = Observation.make!( observed_on_string: "2016-10-27 10am" )
      o2 = Observation.make!( observed_on_string: "2016-10-27 11am" )
      get :index, format: :json, params: { order_by: "observed_on", order: "desc" }
      ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
      expect( ids.first ).to eq o2.id
      expect( ids.last ).to eq o1.id
    end

    describe "filtration by license" do
      before do
        @all_rights = Observation.make!( license: nil )
        expect( @all_rights.license ).to be_nil
        @cc_by = Observation.make!( license: Observation::CC_BY )
      end
      it "should work for any" do
        get :index, format: :json, params: { license: "any" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).not_to include @all_rights.id
        expect( ids ).to include @cc_by.id
      end
      it "should work for none" do
        get :index, format: :json, params: { license: "none" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).to include @all_rights.id
        expect( ids ).not_to include @cc_by.id
      end
      it "should work for CC-BY" do
        get :index, format: :json, params: { license: "CC-BY" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).not_to include @all_rights.id
        expect( ids ).to include @cc_by.id
      end
    end

    describe "filtration by photo_license" do
      before do
        @all_rights = Observation.make!
        photo = LocalPhoto.make!
        make_observation_photo( photo: photo, observation: @all_rights )
        @cc_by = Observation.make!( license: Observation::CC_BY )
        photo = LocalPhoto.make!( license: Photo::CC_BY )
        make_observation_photo( photo: photo, observation: @cc_by )
      end
      it "should work for any" do
        get :index, format: :json, params: { photo_license: "any" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).not_to include @all_rights.id
        expect( ids ).to include @cc_by.id
      end
      it "should work for none" do
        get :index, format: :json, params: { photo_license: "none" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).to include @all_rights.id
        expect( ids ).not_to include @cc_by.id
      end
      it "should work for CC-BY" do
        get :index, format: :json, params: { photo_license: "CC-BY" }
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).not_to include @all_rights.id
        expect( ids ).to include @cc_by.id
      end
    end

    describe "with site" do
      let( :site ) { Site.default( refresh: true ) }
      it "should filter by place" do
        p = make_place_with_geom
        site.update( place: p, preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_PLACE )
        o_inside = Observation.make!( latitude: p.latitude, longitude: p.longitude )
        o_outside = Observation.make!( latitude: -1 * p.latitude, longitude: -1 * p.longitude )
        get :index, format: :json
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).to include o_inside.id
        expect( ids ).not_to include o_outside.id
      end
      it "should filter by site_only_observations" do
        site.update( preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_SITE )
        o_inside = Observation.make!( site: site )
        o_outside = Observation.make!
        get :index, format: :json
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).to include o_inside.id
        expect( ids ).not_to include o_outside.id
      end
      it "should filter by bounding box" do
        site.update(
          preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_BOUNDING_BOX,
          preferred_geo_swlat: 0,
          preferred_geo_swlng: 0,
          preferred_geo_nelat: 1,
          preferred_geo_nelng: 1
        )
        o_inside = Observation.make!( latitude: 0.5, longitude: 0.5 )
        o_outside = Observation.make!( latitude: 2, longitude: 2 )
        get :index, format: :json
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).to include o_inside.id
        expect( ids ).not_to include o_outside.id
      end

      it "should filter by bounding box if place_id set" do
        site.update(
          place: make_place_with_geom,
          preferred_site_observations_filter: Site::OBSERVATIONS_FILTERS_BOUNDING_BOX,
          preferred_geo_swlat: 10,
          preferred_geo_swlng: 10,
          preferred_geo_nelat: 11,
          preferred_geo_nelng: 11
        )
        o_inside = Observation.make!( latitude: 10.5, longitude: 10.5 )
        o_outside = Observation.make!( latitude: 20, longitude: 20 )
        get :index, format: :json
        ids = JSON.parse( response.body ).map {| r | r["id"].to_i }
        expect( ids ).to include o_inside.id
        expect( ids ).not_to include o_outside.id
      end
    end

    describe "should filter when quality_grade" do
      before do
        @research_grade = make_research_grade_observation
        @needs_id = make_research_grade_candidate_observation
        @casual = Observation.make!
      end
      it "research" do
        get :index, format: :json, params: { quality_grade: Observation::RESEARCH_GRADE }
        ids = JSON.parse( response.body ).map {| o | o["id"].to_i }
        expect( ids ).to include @research_grade.id
        expect( ids ).not_to include @needs_id.id
        expect( ids ).not_to include @casual.id
      end
      it "needs_id" do
        get :index, format: :json, params: { quality_grade: Observation::NEEDS_ID }
        ids = JSON.parse( response.body ).map {| o | o["id"].to_i }
        expect( ids ).not_to include @research_grade.id
        expect( ids ).to include @needs_id.id
        expect( ids ).not_to include @casual.id
      end
      it "casual" do
        get :index, format: :json, params: { quality_grade: Observation::CASUAL }
        ids = JSON.parse( response.body ).map {| o | o["id"].to_i }
        expect( ids ).not_to include @research_grade.id
        expect( ids ).not_to include @needs_id.id
        expect( ids ).to include @casual.id
      end
      it "research,needs_id" do
        get :index, format: :json, params: { quality_grade: "#{Observation::RESEARCH_GRADE},#{Observation::NEEDS_ID}" }
        ids = JSON.parse( response.body ).map {| o | o["id"].to_i }
        expect( ids ).to include @research_grade.id
        expect( ids ).to include @needs_id.id
        expect( ids ).not_to include @casual.id
      end
    end

    describe "Simple DarwinCore format" do
      render_views
      it "should render results" do
        o = make_research_grade_observation
        expect( o.photos ).not_to be_blank
        get :index, format: :dwc
        xml = Nokogiri::XML( response.body )
        expect( xml.at_xpath( "//dwr:SimpleDarwinRecordSet" ).children.size ).not_to be_blank
      end
    end

    describe "csv" do
      render_views
      it "should render" do
        o = make_research_grade_observation
        get :index, format: :csv
        CSV.parse( response.body, headers: true ) do | row |
          expect( row["species_guess"] ).to eq o.species_guess
          expect( row["image_url"] ).not_to be_blank
        end
      end
    end

    describe "HTML format" do
      render_views
      before { @o = make_research_grade_observation }
      it "should show the angular app" do
        # the angular app doesn't need to load any observations
        expect( Observation ).not_to receive( :get_search_params )
        get :index, format: :html
        expect( response.body ).to match( /ng-controller=.MapController/ )
        expect( response.body ).to_not have_tag( "div.user a", text: @o.user.login )
      end

      it "can render a partial instead" do
        # we need observations to render all other partials/formats
        expect( Observation ).to receive( :get_search_params )
        get :index, format: :html, params: { partial: "observation_component" }
        expect( response.body ).to_not include "ng-controller='MapController'"
        expect( response.body ).to have_tag( "div.user a", text: @o.user.login )
      end
    end
  end

  describe "taxon_stats" do
    elastic_models( Observation, Place )
    before do
      @o = Observation.make!( observed_on_string: "2013-07-20", taxon: Taxon.make!( rank: Taxon::SPECIES ) )
      get :taxon_stats, format: :json, params: { on: "2013-07-20" }
      @json = JSON.parse( response.body )
    end

    it "should include a total" do
      expect( @json["total"].to_i ).to be > 0
    end

    it "should include species_counts" do
      expect( @json["species_counts"].size ).to be > 0
    end

    it "should include rank_counts" do
      expect( @json["rank_counts"][@o.taxon.rank.downcase] ).to be > 0
    end
  end

  describe "user_stats" do
    elastic_models( Observation, Place )
    before do
      @o = Observation.make!(
        observed_on_string: "2013-07-20",
        taxon: Taxon.make!( rank: Taxon::SPECIES )
      )
      get :user_stats, format: :json, params: { on: "2013-07-20" }
      @json = JSON.parse( response.body )
    end

    it "should include a total" do
      expect( @json["total"].to_i ).to be > 0
    end

    it "should include most_observations" do
      expect( @json["most_observations"].size ).to be > 0
    end

    it "should include most_species" do
      expect( @json["most_species"].size ).to be > 0
    end

    it "should include user name" do
      expect( @json["most_observations"][0]["user"]["name"] ).to eq @o.user.name
    end
  end

  describe "viewed_updates" do
    before do
      enable_has_subscribers
      after_delayed_job_finishes( ignore_run_at: true ) do
        @o = Observation.make!( user: user )
        @c = Comment.make!( parent: @o )
        @i = Identification.make!( observation: @o )
      end
    end
    after { disable_has_subscribers }

    it "should mark all updates from this observation for the signed in user as viewed" do
      expect( UpdateAction.unviewed_by_user_from_query( user.id, resource: @o ) ).to eq true
      put :viewed_updates, format: :json, params: { id: @o.id }
      expect( UpdateAction.unviewed_by_user_from_query( user.id, resource: @o ) ).to eq false
    end

    it "should not mark other updates for the signed in user as viewed" do
      without_delay do
        o = Observation.make!( user: user )
        Comment.make!( parent: o )
      end
      expect( UpdateAction.unviewed_by_user_from_query( user.id, resource: @o ) ).to eq true
      expect( UpdateAction.unviewed_by_user_from_query( @c.user_id, resource: @o ) ).to eq true
      without_delay do
        put :viewed_updates, format: :json, params: { id: @o.id }
      end
      expect( UpdateAction.unviewed_by_user_from_query( user.id, resource: @o ) ).to eq false
      expect( UpdateAction.unviewed_by_user_from_query( @c.user_id, resource: @o ) ).to eq true
    end

    it "should not mark other updates from this observation as viewed" do
      expect( UpdateAction.unviewed_by_user_from_query( user.id, resource: @o ) ).to eq true
      expect( UpdateAction.unviewed_by_user_from_query( @c.user_id, resource: @o ) ).to eq true
      put :viewed_updates, format: :json, params: { id: @o.id }
      expect( UpdateAction.unviewed_by_user_from_query( user.id, resource: @o ) ).to eq false
      expect( UpdateAction.unviewed_by_user_from_query( @c.user_id, resource: @o ) ).to eq true
    end
  end

  describe "update_fields" do
    elastic_models( Observation )
    shared_examples_for "it allows changes" do
      it "should allow ofv creation" do
        put :update_fields, format: :json, params: { id: o.id, observation: {
          observation_field_values_attributes: {
            "0" => {
              observation_field_id: of.id,
              value: "foo"
            }
          }
        } }
        expect( response ).to be_successful
        o.reload
        expect( o.observation_field_values.first.value ).to eq "foo"
      end
      it "should allow ofv updating" do
        ObservationFieldValue.make!( observation: o, observation_field: of, value: "foo" )
        put :update_fields, format: :json, params: { id: o.id, observation: {
          observation_field_values_attributes: {
            "0" => {
              observation_field_id: of.id,
              value: "bar"
            }
          }
        } }
        expect( response ).to be_successful
        o.reload
        expect( o.observation_field_values.first.value ).to eq "bar"
      end
    end

    describe "for the observer" do
      let( :o ) { Observation.make!( user: user ) }
      let( :of ) { ObservationField.make! }
      it_behaves_like "it allows changes"
      it "should add to a project when project_id included" do
        p = Project.make!
        ProjectUser.make!( user: o.user, project: p )
        put :update_fields, format: :json, params: { id: o.id, project_id: p.id, observation: {
          observation_field_values_attributes: {
            "0" => {
              observation_field_id: of.id,
              value: "foo"
            }
          }
        } }
        expect( ProjectObservation.where( project_id: p, observation_id: o ).exists? ).to be true
      end
      it "adds the project observation to elasticsearch" do
        p = Project.make!
        ProjectUser.make!( user: o.user, project: p )
        o.elastic_index!
        expect( Observation.elastic_search( where: { id: o.id } ).
          results.results.first.project_ids ).to eq []
        # TODO: Rails 5 behavior change? This used to work w/ observation_field_values_attributes: { }
        put :update_fields, format: :json, params: { id: o.id, project_id: p.id, observation: {
          observation_field_values_attributes: {
            "0" => {
              observation_field_id: of.id,
              value: "foo"
            }
          }
        } }
        expect( Observation.elastic_search( where: { id: o.id } ).
          results.results.first.project_ids ).to eq [p.id]
      end
    end

    describe "for a non-observer" do
      let( :o ) { Observation.make! }
      let( :of ) { ObservationField.make! }
      it_behaves_like "it allows changes"
      it "should set the user_id" do
        put :update_fields, format: :json, params: { id: o.id, observation: {
          observation_field_values_attributes: {
            "0" => {
              observation_field_id: of.id,
              value: "foo"
            }
          }
        } }
        expect( response ).to be_successful
        o.reload
        expect( o.observation_field_values.first.user ).to eq user
        expect( o.observation_field_values.first.updater ).to eq user
      end
    end

    describe "for a curator" do
      before do
        user.roles << Role.make!( name: "curator" )
      end
      let( :o ) { Observation.make! }
      let( :of ) { ObservationField.make! }

      it "should allow creation if observer prefers editng by curators" do
        u = o.user
        u.update( preferred_observation_fields_by: User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS )
        expect( u.preferred_observation_fields_by ).to eq User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS
        o.reload
        put :update_fields, format: :json, params: { id: o.id, observation: {
          observation_field_values_attributes: {
            "0" => {
              observation_field_id: of.id,
              value: "foo"
            }
          }
        } }
        expect( response ).to be_successful
        o.reload
        expect( o.observation_field_values.first.value ).to eq "foo"
      end
      it "should not allow creation if observer prefers editng by observer" do
        o.user.update( preferred_observation_fields_by: User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER )
        expect( o.user.preferred_observation_fields_by ).to eq User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER
        put :update_fields, format: :json, params: { id: o.id, observation: {
          observation_field_values_attributes: {
            "0" => {
              observation_field_id: of.id,
              value: "foo"
            }
          }
        } }
        expect( response ).not_to be_successful
        o.reload
        expect( o.observation_field_values ).to be_blank
      end
    end
  end

  describe "review" do
    let( :o ) { Observation.make! }
    it "should mark an observation as reviewed by the current user" do
      post :review, format: :json, params: { id: o.id }
      o.reload
      expect( o ).to be_reviewed_by user
    end
    describe "should unreview" do
      before do
        ObservationReview.make!( observation: o, user: user )
        o.reload
        expect( o ).to be_reviewed_by user
      end
      it "should unreview in response to a param" do
        post :review, format: :json, params: { id: o.id, reviewed: "false" }
        o.reload
        expect( o ).not_to be_reviewed_by user
      end
      it "should unreview in response to DELETE" do
        delete :review, format: :json, params: { id: o.id }
        o.reload
        expect( o ).not_to be_reviewed_by user
      end
    end
  end

  describe "project" do
    elastic_models( Observation )
    let( :project_observation ) { make_project_observation }
    before { expect( project_observation.project.observations.count ).to eq 1 }
    # There are some Rails API consumers, but IMO, worth deprecating when we
    # deprecate the Rails API as a public-facing API
    it "should return JSON" do
      get :project, format: "json", params: { id: project_observation.project_id }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      json_obs = json[0]
      expect( json_obs["id"] ).to eq project_observation.observation_id
    end
  end
end

shared_examples_for "an ObservationsController for a remembered user" do
  before do
    # Forgery protection seems to be turned off by default, so we need to turn it on here
    ActionController::Base.allow_forgery_protection = true
    user.update( remember_token: "foo", remember_created_at: Time.now )
  end

  after do
    ActionController::Base.allow_forgery_protection = false
  end

  describe "create" do
    it "should not remove the user's remember_token" do
      expect( user.remember_token ).not_to be_blank
      post :create, format: "json", params: { observation: { species_guess: "foo" } }
      expect( response ).to be_successful
      user.reload
      expect( user.remember_token ).not_to be_blank
    end
  end
end

describe ObservationsController, "oauth authentication" do
  let( :user ) { User.make! }
  before do
    token = Doorkeeper::AccessToken.create(
      application: OauthApplication.make!,
      resource_owner_id: user.id,
      scopes: Doorkeeper.configuration.default_scopes
    )
    request.env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}"
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "ObservationsController basics"
  it_behaves_like "an ObservationsController"
  it_behaves_like "an ObservationsController for a remembered user"
end

describe ObservationsController, "jwt authentication" do
  let( :user ) { User.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = JsonWebToken.encode( user_id: user.id )
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "ObservationsController basics"
  it_behaves_like "an ObservationsController for a remembered user"
end

describe ObservationsController, "jwt bearer authentication" do
  let( :user ) { User.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer #{JsonWebToken.encode( user_id: user.id )}"
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "ObservationsController basics"
end

describe ObservationsController, "without authentication" do
  describe "index" do
    elastic_models( Observation )
    it "should require sign in for page 100 or more" do
      get :index, format: :json, params: { page: 10 }
      expect( response ).to be_successful
      get :index, format: :json, params: { page: 101 }
      expect( response.status ).to eq 401
    end
  end
  describe "create" do
    it "should be impossible" do
      post :create, format: :json, params: { observation: { species_guess: "foo" } }
      expect( response.status ).to eq 401
    end
  end
end
