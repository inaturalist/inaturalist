# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe ObservationsController do
  elastic_models( Observation )
  describe "create" do
    let( :user ) { User.make! }
    before do
      sign_in user
    end
    it "should not raise an exception if the obs was invalid and an image was submitted"

    it "should not raise an exception if no observations passed" do
      expect do
        post :create
      end.to_not raise_error
    end

    it "should add project observations if auto join project specified" do
      project = Project.make!
      expect( project.users.find_by_id( user.id ) ).to be_blank
      post :create, params: { observation: { species_guess: "Foo!" }, project_id: project.id, accept_terms: true }
      expect( project.users.find_by_id( user.id ) ).to be_blank
      expect( project.observations.last.id ).to eq Observation.last.id
    end

    it "should add project observations to elasticsearch" do
      project = Project.make!
      expect( project.users.find_by_id( user.id ) ).to be_blank
      post :create, params: { observation: { species_guess: "Foo!" }, project_id: project.id, accept_terms: true }
      expect( project.observations.last.id ).to eq Observation.last.id
      expect( Observation.elastic_search( where: { id: Observation.last.id } ).
        results.results.first.project_ids ).to eq [project.id]
    end

    it "should add project observations if auto join project specified and format is json" do
      project = Project.make!
      expect( project.users.find_by_id( user.id ) ).to be_blank
      post :create, format: "json", params: { observation: { species_guess: "Foo!" }, project_id: project.id }
      expect( project.users.find_by_id( user.id ) ).to be_blank
      expect( project.observations.last.id ).to eq Observation.last.id
    end

    it "should set taxon from taxon_name param" do
      taxon = Taxon.make!
      post :create, params: { observation: { species_guess: "Foo", taxon_name: taxon.name } }
      obs = user.observations.last
      expect( obs ).to_not be_blank
      expect( obs.taxon_id ).to eq taxon.id
      expect( obs.species_guess ).to eq "Foo"
    end

    it "should set the site" do
      @site = Site.make!
      post :create, params: { observation: { species_guess: "Foo" }, site_id: @site.id, inat_site_id: @site.id }
      expect( user.observations.last.site ).to_not be_blank
      expect( user.observations.last.site.id ).to eq @site.id
    end

    it "should survive submitting an invalid observation to a project" do
      p = Project.make!
      ProjectObservationRule.make!( operator: "georeferenced?", ruler: p )
      expect do
        post :create, params: {
          observation: { species_guess: "foo", observed_on_string: 1.year.from_now.to_date.to_s }, project_id: p.id
        }
      end.not_to raise_error
    end

    it "should work with a custom coordinate system" do
      nztm_proj4 = "+proj=tmerc +lat_0=0 +lon_0=173 +k=0.9996 +x_0=1600000 " \
        "+y_0=10000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
      post :create, params: { observation: {
        geo_x: 1_889_191,
        geo_y: 5_635_569,
        coordinate_system: nztm_proj4
      } }
      o = user.observations.last
      # different versions of proj seem to change the precision of this float
      expect( o.latitude.to_f ).to be_in( [-39.380943828, -39.3809438281] )
      expect( o.longitude.to_f ).to eq 176.3574072522
    end

    it "should mark the observation as reviewed by the observer if there was a taxon" do
      taxon = Taxon.make!
      post :create, params: { observation: { taxon_id: taxon.id } }
      o = user.observations.last
      expect( o ).to be_reviewed_by( o.user )
    end
  end

  describe "update" do
    it "should not raise an exception if no observations passed" do
      user = User.make!
      sign_in user

      expect do
        post :update
      end.to_not raise_error
    end

    it "should use latitude param even if private_latitude set" do
      observation = Observation.make!( taxon: make_threatened_taxon, latitude: 38, longitude: -122 )
      expect( observation.private_longitude ).to_not be_blank
      old_latitude = observation.latitude
      old_private_latitude = observation.private_latitude
      sign_in observation.user
      post :update, params: { id: observation.id, observation: { latitude: 1 } }
      observation.reload
      expect( observation.private_longitude ).to_not be_blank
      expect( observation.latitude.to_f ).to_not eq old_latitude.to_f
      expect( observation.private_latitude.to_f ).to_not eq old_private_latitude.to_f
    end

    describe "with captive_flag" do
      let( :o ) { Observation.make! }
      before do
        sign_in o.user
      end
      it "should set captive" do
        expect( o ).not_to be_captive
        patch :update, params: { id: o.id, observation: { captive_flag: "1" } }
        o.reload
        expect( o ).to be_captive
      end
      it "should set a quality_metric" do
        expect( o.quality_metrics ).to be_blank
        patch :update, params: { id: o.id, observation: { captive_flag: "1" } }
        o.reload
        expect( o.quality_metrics ).not_to be_blank
      end
    end

    describe "license changes" do
      let( :u ) { User.make! }
      let( :past_o ) { Observation.make!( user: u, license: nil ) }
      let( :o ) { Observation.make!( user: u, license: nil ) }
      before do
        expect( u.preferred_observation_license ).to be_nil
        expect( past_o.license ).to be_nil
        expect( o.license ).to be_nil
        sign_in u
      end
      it "should update the license of the observation" do
        without_delay do
          put :update, params: { id: o.id, observation: { license: Observation::CC_BY } }
        end
        o.reload
        expect( o.license ).to eq Observation::CC_BY
      end
      it "should update user default" do
        without_delay do
          put :update, params: { id: o.id, observation: { license: Observation::CC_BY, make_license_default: true } }
        end
        u.reload
        expect( u.preferred_observation_license ).to eq Observation::CC_BY
      end
      it "should update past licenses" do
        without_delay do
          put :update, params: { id: o.id, observation: { license: Observation::CC_BY, make_licenses_same: true } }
        end
        past_o.reload
        expect( past_o.license ).to eq Observation::CC_BY
      end
    end

    it "should allow updating with more than one photo" do
      o = Observation.make!
      sign_in o.user
      expect( o.photos.size ).to eq 0
      fixture_file_upload( "../observations.csv", "text/csv" )
      put :update, params: { id: o.id, observation: { description: "+2 photos" }, local_photos: {
        o.id.to_s => [
          fixture_file_upload( "cuthona_abronia-tagged.jpg", "image/jpeg" ),
          fixture_file_upload( "cuthona_abronia-tagged.jpg", "image/jpeg" )
        ]
      } }
      o.reload
      expect( o.photos.size ).to eq 2
    end

    it "should support updating multiple observations" do
      user = User.make!
      sign_in user
      o1 = Observation.make!( description: "foo", user: user )
      o2 = Observation.make!( description: "bar", user: user )
      post :update, params: { observations: {
        o1.id => { description: "foo1" },
        o2.id => { description: "bar1" }
      } }
      o1.reload
      o2.reload
      expect( o1.description ).to eq "foo1"
      expect( o2.description ).to eq "bar1"
    end
  end

  describe "show" do
    render_views
    let( :observation ) { Observation.make! }
    it "should not include the place_guess when coordinates obscured" do
      original_place_guess = "Duluth, MN"
      o = Observation.make!( geoprivacy: Observation::OBSCURED, latitude: 1, longitude: 1,
        place_guess: original_place_guess )
      get :show, params: { id: o.id }
      expect( response.body ).not_to be =~ /#{original_place_guess}/
    end

    it "should 404 for absurdly large ids" do
      get :show, params: { id: 123_123_123_123_123_123 }
      expect( response ).to be_not_found
    end

    it "renders a self-referential canonical tag" do
      get :show, params: { id: observation.id }
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{observation_url( observation, host: Site.default.url )}']"
      )
    end

    it "renders a canonical tag from other sites to default site" do
      different_site = Site.make!
      get :show, params: { id: observation.id, inat_site_id: different_site.id }
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{observation_url( observation, host: Site.default.url )}']"
      )
    end

    describe "opengraph description" do
      it "should include not be blank if there's a taxon, date, and place_guess" do
        o = make_research_grade_candidate_observation( taxon: Taxon.make!, place_guess: "this rad pad" )
        expect( o.taxon ).not_to be_blank
        expect( o.observed_on ).not_to be_blank
        expect( o.place_guess ).not_to be_blank
        desc = o.to_plain_s
        expect( desc ).not_to be =~ /something/i
        get :show, params: { id: o.id }
        html = Nokogiri::HTML( response.body )
        og_desc = html.at( "meta[property='og:description']" )
        expect( og_desc[:content] ).to match( /#{desc}/ )
      end

      it "should include the taxon's common name if there's a taxon but no species_guess" do
        t = TaxonName.make!( lexicon: "English" ).taxon
        o = make_research_grade_candidate_observation( taxon: t )
        get :show, params: { id: o.id }
        html = Nokogiri::HTML( response.body )
        og_desc = html.at( "meta[property='og:description']" )
        expect( o.taxon.common_name ).not_to be_blank
        expect( og_desc[:content] ).to match( /#{o.taxon.common_name.name}/ )
      end
    end
  end

  describe "by_login_all", "page cache" do
    before do
      @observation = Observation.make!
      @user = @observation.user
      path = observations_by_login_all_path( @user.login, format: "csv" )
      FileUtils.rm private_page_cache_path( path ), force: true
      sign_in @user
    end

    it "should set after request" do
      without_delay do
        get :by_login_all, format: :csv, params: { login: @user.login }
      end
      expect( response ).to be_private_page_cached
    end

    it "should be cleared by new observations" do
      without_delay do
        get :by_login_all, format: :csv, params: { login: @user.login }
      end
      expect( response ).to be_private_page_cached
      post :create, params: { observation: { species_guess: "foo" } }
      expect( observations_by_login_all_path( @user.login, format: :csv ) ).to_not be_private_page_cached
    end
  end

  describe "project" do
    let( :project ) { Project.make! }
    let( :project_observation ) { make_project_observation( project: project ) }
    before { expect( project_observation ).not_to be_blank }
    # Apparently people use the project widget
    it "render widget content" do
      get :project, format: "widget", params: { id: project.id }
      expect( response ).to be_successful
    end
  end

  describe "project_all", "page cache" do
    before do
      @project = Project.make!
      @user = @project.user
      @observation = Observation.make!( user: @user )
      @project_observation = make_project_observation( project: @project, observation: @observation,
        user: @observation.user )
      @observation = @project_observation.observation
      ActionController::Base.perform_caching = true
      path = all_project_observations_path( @project, format: "csv" )
      FileUtils.rm private_page_cache_path( path ), force: true
      sign_in @user
    end

    after do
      ActionController::Base.perform_caching = false
    end

    it "should set after request" do
      without_delay do
        get :project_all, format: :csv, params: { id: @project }
      end
      expect( response ).to be_private_page_cached
    end

    it "should be cleared by new observations" do
      without_delay do
        get :project_all, format: :csv, params: { id: @project }
      end
      expect( response ).to be_private_page_cached
      post :destroy, params: { id: @observation }
      expect( all_project_observations_path( @project, format: :csv ) ).to_not be_private_page_cached
    end
    describe "when viewed by a project curator" do
      before do
        ProjectUser.where( user: @user, project: @project ).
          update_all( role: ProjectUser::CURATOR )
        expect( @project ).to be_curated_by @user
      end
      it "should include private coordinates for observations with geoprivacy" do
        @observation.update(
          geoprivacy: Observation::PRIVATE,
          latitude: 1.2345,
          longitude: 1.2345
        )
        expect( @observation ).to be_coordinates_obscured
        expect( @project_observation ).to be_prefers_curator_coordinate_access
        get :project_all, format: :csv, params: { id: @project }
        target_row = nil
        CSV.parse( response.body, headers: true ) do | row |
          if row["id"].to_i == @observation.id
            target_row = row
          end
        end
        expect( target_row ).not_to be_blank
        expect( target_row["private_latitude"] ).not_to be_blank
        expect( target_row["private_longitude"] ).not_to be_blank
      end

      it "should include private coordinates for observations of threatened taxa" do
        @observation.update(
          latitude: 1.2345,
          longitude: 1.2345,
          taxon: make_threatened_taxon,
          editing_user_id: @observation.user_id
        )
        expect( @observation ).to be_coordinates_obscured
        expect( @project_observation ).to be_prefers_curator_coordinate_access
        get :project_all, format: :csv, params: { id: @project }
        target_row = nil
        CSV.parse( response.body, headers: true ) do | row |
          if row["id"].to_i == @observation.id
            target_row = row
          end
        end
        expect( target_row ).not_to be_blank
        expect( target_row["private_latitude"] ).not_to be_blank
        expect( target_row["private_longitude"] ).not_to be_blank
      end
    end
  end

  describe "by_login_all" do
    it "should include observation fields" do
      of = ObservationField.make!( name: "count", datatype: "numeric" )
      ofv = ObservationFieldValue.make!( observation_field: of, value: 7 )
      user = ofv.observation.user
      sign_in user
      get :by_login_all, format: :csv, params: { login: user.login }
      expect( response.body ).to be =~ /field:count/
    end
  end

  describe "project_all", "csv" do
    it "should include observation fields" do
      of = ObservationField.make!( name: "count", datatype: "numeric" )
      pof = ProjectObservationField.make!( observation_field: of )
      p = pof.project
      po = make_project_observation( project: p )
      ObservationFieldValue.make!( observation_field: of, value: 7, observation: po.observation )
      sign_in p.user
      get :project_all, format: :csv, params: { id: p.id }
      expect( response.body ).to be =~ /field:count/
    end

    it "should have project-specific fields" do
      p = Project.make!
      sign_in p.user
      get :project_all, format: :csv, params: { id: p.id }
      %w(curator_ident_taxon_id curator_ident_taxon_name curator_ident_user_id curator_ident_user_login
         tracking_code).each do | f |
        expect( response.body ).to be =~ /#{f}/
      end
    end

    it "should have private coordinates for curators" do
      po = make_project_observation
      po.observation.update( latitude: 9.8765, longitude: 4.321, geoprivacy: Observation::PRIVATE )
      p = po.project
      expect( p.user ).not_to be po.observation.user
      sign_in p.user
      expect( p ).to be_curated_by p.user
      get :project_all, format: :csv, params: { id: p.id }
      expect( response.body ).to be =~ /private_latitude/
      expect( response.body ).to be =~ /#{po.observation.private_latitude}/
      expect( response.body ).to be =~ /#{po.observation.private_longitude}/
    end

    it "should not have private_coordinates when curator_coordinate_access is false" do
      o = Observation.make!( latitude: 1.2345, longitude: 1.2345, geoprivacy: Observation::OBSCURED )
      po = ProjectObservation.make!( observation: o )
      expect( po.observation ).to be_coordinates_obscured
      expect( po.project.project_users.where( user_id: po.observation.user_id ) ).to be_blank
      expect( po ).not_to be_prefers_curator_coordinate_access
      sign_in po.project.user
      get :project_all, format: :csv, params: { id: po.project_id }
      expect( response.body ).to be =~ /private_latitude/
      expect( response.body ).not_to be =~ /#{po.observation.private_latitude}/
    end
  end

  describe "curation" do
    render_views
    before :each do
      @curator = make_curator
      sign_in( @curator )
    end

    it "should render a link to the flagger" do
      Flag.make!( user: @curator, flaggable: Observation.make! )
      get :curation
      expect( response.body ).to have_selector( "table td", text: @curator.login )
      expect( response.body ).to_not have_selector( "table td", text: Site.default.site_name_short )
    end

    it "should show site.site_name_short if there is no flagger" do
      Flag.make!( flaggable: Observation.make! )
      Flag.last.update_column( :user_id, 0 )
      get :curation
      expect( response.body ).to_not have_selector( "table td", text: @curator.login )
      expect( response.body ).to have_selector( "table td", text: Site.default.site_name_short )
    end
  end

  describe "index" do
    let( :user ) { User.make! }
    before { sign_in user }

    render_views

    it "should not raise an exception with malformed date params" do
      expect do
        get :index, params: { on: "2020-09", user_id: user.id }
      end.not_to raise_exception
    end

    it "should just ignore project slugs for projects that don't exist" do
      expect do
        get :index, params: { projects: "imaginary-project" }
      end.not_to raise_error
    end

    it "should include https image urls in widget response" do
      make_research_grade_observation
      request.env["HTTPS"] = "on"
      get :index, format: :widget
      expect( response.body ).to match( /s3.amazonaws.com/ )
    end
  end

  describe "review" do
    let( :obs_to_review ) { Observation.make! }
    it "forces users to log in when requesting HTML" do
      controller.request.host = URI.parse( Site.default.url ).host
      post :review, format: :html, params: { id: obs_to_review }
      expect( response.response_code ).to eq 302
      expect( response ).to be_redirect
      expect( response ).to redirect_to( new_user_session_url )
    end
    it "denies non-logged-in users when requesting JSON" do
      post :review, format: :json, params: { id: obs_to_review }
      expect( response.response_code ).to eq 401
      json = JSON.parse( response.body.to_s )
      expect( json["error"] ).to eq "You need to sign in or sign up before continuing."
    end
    it "allows logged-in requests" do
      sign_in obs_to_review.user
      post :review, format: :json, params: { id: obs_to_review }
      expect( response.response_code ).to eq 204
      expect( response.body ).to be_blank
    end
    it "redirects HTML requests to the observations page" do
      sign_in obs_to_review.user
      post :review, format: :html, params: { id: obs_to_review }
      expect( response.response_code ).to eq 302
      expect( response ).to redirect_to( observation_url( obs_to_review ) )
    end
    it "creates an observation review if one does not exist" do
      obs_to_review.observation_reviews.destroy_all
      reviewer = User.make!
      expect( obs_to_review.observation_reviews.where( user_id: reviewer.id ).size ).to eq 0
      sign_in reviewer
      post :review, params: { id: obs_to_review }
      obs_to_review.reload
      expect( obs_to_review.observation_reviews.where( user_id: reviewer.id ).size ).to eq 1
      expect( obs_to_review.observation_reviews.first.reviewed ).to eq true
      expect( obs_to_review.observation_reviews.first.user_added ).to eq true
    end
    it "updates an existing observation review" do
      obs_to_review.observation_reviews.destroy_all
      reviewer = User.make!
      expect( obs_to_review.observation_reviews.where( user_id: reviewer.id ).size ).to eq 0
      sign_in reviewer
      post :review, params: { id: obs_to_review }
      obs_to_review.reload
      expect( obs_to_review.observation_reviews.where( user_id: reviewer.id ).size ).to eq 1
      expect( obs_to_review.observation_reviews.first.reviewed ).to eq true
      post :review, params: { id: obs_to_review, reviewed: "false" }
      obs_to_review.reload
      expect( obs_to_review.observation_reviews.where( user_id: reviewer.id ).size ).to eq 1
      expect( obs_to_review.observation_reviews.first.reviewed ).to eq false
    end
  end

  describe "export" do
    let( :user ) { User.make! }
    before do
      sign_in user
    end
    it "should assign flow_task_id that belongs to the current user" do
      flow_task = make_observations_export_flow_task( user: user )
      get :export, params: { flow_task_id: flow_task.id }
      expect( assigns( :flow_task ) ).to eq flow_task
    end
    it "should not assign flow_task_id that belongs to another user" do
      flow_task = make_observations_export_flow_task
      get :export, params: { flow_task_id: flow_task.id }
      expect( assigns( :flow_task ) ).to be_blank
    end
  end
end

describe ObservationsController, "spam" do
  let( :spammer_content ) do
    o = Observation.make!
    o.user.update( spammer: true )
    o
  end
  let( :flagged_content ) do
    o = Observation.make!
    Flag.make!( flaggable: o, flag: Flag::SPAM )
    o
  end

  it "should render 403 when the owner is a spammer" do
    get :show, params: { id: spammer_content.id }
    expect( response.response_code ).to eq 403
  end

  it "should render 403 when content is flagged as spam" do
    get :show, params: { id: spammer_content.id }
    expect( response.response_code ).to eq 403
  end
end

describe ObservationsController, "new_batch" do
  describe "routes" do
    before do
      sign_in User.make!
    end
    it "should accept GET requests" do
      expect( get: "/observations/new/batch" ).to be_routable
    end
    it "should accept POST requests" do
      expect( post: "/observations/new/batch" ).to be_routable
    end
  end
end

describe ObservationsController, "new_bulk_csv" do
  let( :work_path ) { File.join( Dir.tmpdir, "new_bulk_csv-#{Time.now.to_i}.csv" ) }
  let( :headers ) do
    %w(taxon_name date_observed description place_name latitude longitude tags geoprivacy)
  end
  let( :user ) { User.make! }
  before do
    sign_in user
  end
  it "should not allow you to enqueue the same file twice" do
    Delayed::Job.delete_all
    post :new_bulk_csv, params: { upload: { datafile: fixture_file_upload( "../observations.csv", "text/csv" ) } }
    expect( response ).to be_redirect
    expect( Delayed::Job.count ).to eq 1
    sleep( 2 )
    post :new_bulk_csv, params: { upload: { datafile: fixture_file_upload( "../observations.csv", "text/csv" ) } }
    expect( Delayed::Job.count ).to eq 1
  end

  it "should allow you to enqueue different files" do
    Delayed::Job.delete_all
    CSV.open( work_path, "w" ) do | csv |
      csv << headers
      csv << [
        "Homo sapiens",
        "2015-01-01",
        "Too many of them",
        "San Francisco",
        "37.7693",
        "-122.46565",
        "foo,bar",
        "open"
      ]
      csv
    end
    post :new_bulk_csv, params: { upload: { datafile: Rack::Test::UploadedFile.new( work_path, "text/csv" ) } }
    expect( response ).to be_redirect
    expect( Delayed::Job.count ).to eq 1
    post :new_bulk_csv, params: { upload: { datafile: fixture_file_upload( "../observations.csv", "text/csv" ) } }
    expect( Delayed::Job.count ).to eq 2
  end

  it "should create observations" do
    Delayed::Job.delete_all
    Observation.by( user ).destroy_all
    expect( Observation.by( user ).count ).to eq 0
    CSV.open( work_path, "w" ) do | csv |
      csv << headers
      csv << [
        "Homo sapiens",
        "2015-01-01",
        "Too many of them",
        "San Francisco",
        "37.7693",
        "-122.46565",
        "foo,bar",
        "open"
      ]
      csv
    end
    Taxon.make!( name: "Homo sapiens" )
    post :new_bulk_csv, params: { upload: { datafile: Rack::Test::UploadedFile.new( work_path, "text/csv" ) } }
    Delayed::Worker.new.work_off
    expect( Observation.by( user ).count ).to eq 1
  end

  it "should create observations with custom coordinate systems" do
    # rubocop:disable Layout/LineLength
    Site.default.update( coordinate_systems_json: '{
      "nztm2000": {
        "label": "NZTM2000 (NZ Transverse Mercator), EPSG:2193",
        "proj4": "+proj=tmerc +lat_0=0 +lon_0=173 +k=0.9996 +x_0=1600000 +y_0=10000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
      },
      "nzmg": {
        "label": "NZMG (New Zealand Map Grid), EPSG:27200",
        "proj4": "+proj=nzmg +lat_0=-41 +lon_0=173 +x_0=2510000 +y_0=6023150 +ellps=intl +datum=nzgd49 +units=m +no_defs"
      }
    }' )
    # rubocop:enable Layout/LineLength
    expect( Site.default.coordinate_systems ).not_to be_blank
    Delayed::Job.delete_all
    Observation.by( user ).destroy_all
    expect( Observation.by( user ).count ).to eq 0
    CSV.open( work_path, "w" ) do | csv |
      csv << headers
      csv << [
        "Homo sapiens",
        "2015-01-01",
        "Too many of them",
        "San Francisco",
        5_635_569, # these coordinates should be NZMG for Lat -39.380943828, Lon 176.3574072522
        1_889_191,
        "foo,bar",
        "open"
      ]
      csv
    end
    Taxon.make!( name: "Homo sapiens" )
    post :new_bulk_csv, params: { upload: {
      datafile: Rack::Test::UploadedFile.new( work_path, "text/csv" ),
      coordinate_system: "nzmg"
    } }
    Delayed::Worker.new.work_off
    expect( Observation.by( user ).count ).to eq 1
  end
end
