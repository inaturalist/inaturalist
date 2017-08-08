require File.dirname(__FILE__) + '/../spec_helper'

describe ObservationsController do
  describe "create" do
    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }
    render_views
    let(:user) { User.make! }
    before do
      sign_in user
    end
    it "should not raise an exception if the obs was invalid and an image was submitted"
    
    it "should not raise an exception if no observations passed" do
      expect {
        post :create
      }.to_not raise_error
    end
    
    it "should add project observations if auto join project specified" do
      project = Project.make!
      expect(project.users.find_by_id(user.id)).to be_blank
      post :create, :observation => {:species_guess => "Foo!"}, :project_id => project.id, :accept_terms => true
      expect(project.users.find_by_id(user.id)).to be_blank
      expect(project.observations.last.id).to eq Observation.last.id
    end

    it "should add project observations to elasticsearch" do
      project = Project.make!
      expect(project.users.find_by_id(user.id)).to be_blank
      post :create, :observation => {:species_guess => "Foo!"}, :project_id => project.id, :accept_terms => true
      expect(project.observations.last.id).to eq Observation.last.id
      expect(Observation.elastic_search(where: { id: Observation.last.id }).
        results.results.first.project_ids).to eq [ project.id ]
    end

    it "should add project observations if auto join project specified and format is json" do
      project = Project.make!
      expect(project.users.find_by_id(user.id)).to be_blank
      post :create, :format => "json", :observation => {:species_guess => "Foo!"}, :project_id => project.id
      expect(project.users.find_by_id(user.id)).to be_blank
      expect(project.observations.last.id).to eq Observation.last.id
    end
    
    it "should set taxon from taxon_name param" do
      taxon = Taxon.make!
      post :create, :observation => {:species_guess => "Foo", :taxon_name => taxon.name}
      obs = user.observations.last
      expect(obs).to_not be_blank
      expect(obs.taxon_id).to eq taxon.id
      expect(obs.species_guess).to eq "Foo"
    end
    
    it "should set the site" do
      @site = Site.make!
      post :create, observation: { species_guess: "Foo" }, site_id: @site.id, inat_site_id: @site.id
      expect( user.observations.last.site ).to_not be_blank
      expect( user.observations.last.site.id ).to eq @site.id
    end

    it "should survive submitting an invalid observation to a project" do
      p = Project.make!
      por = ProjectObservationRule.make!(operator: 'georeferenced?', ruler: p)
      expect {
        post :create, observation: {species_guess: 'foo', observed_on_string: 1.year.from_now.to_date.to_s}, project_id: p.id
      }.not_to raise_error
    end

    it "should work with a custom coordinate system" do
      nztm_proj4 = "+proj=tmerc +lat_0=0 +lon_0=173 +k=0.9996 +x_0=1600000 +y_0=10000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
      post :create, observation: {
        geo_x: 1889191,
        geo_y: 5635569,
        coordinate_system: nztm_proj4
      }
      o = user.observations.last
      expect( o.latitude ).to eq -39.380943828
      expect( o.longitude ).to eq 176.3574072522
    end

  end
  
  describe "update" do
    it "should not raise an exception if no observations passed" do
      user = User.make!
      sign_in user
      
      expect {
        post :update
      }.to_not raise_error
    end
    
    it "should use latitude param even if private_latitude set" do
      observation = Observation.make!(:taxon => make_threatened_taxon, :latitude => 38, :longitude => -122)
      expect(observation.private_longitude).to_not be_blank
      old_latitude = observation.latitude
      old_private_latitude = observation.private_latitude
      sign_in observation.user
      post :update, :id => observation.id, :observation => {:latitude => 1}
      observation.reload
      expect(observation.private_longitude).to_not be_blank
      expect(observation.latitude.to_f).to_not eq old_latitude.to_f
      expect(observation.private_latitude.to_f).to_not eq old_private_latitude.to_f
    end

    describe "with captive_flag" do
      let(:o) { Observation.make! }
      before do
        sign_in o.user
      end
      it "should set captive" do
        expect(o).not_to be_captive
        patch :update, id: o.id, observation: {captive_flag: '1'}
        o.reload
        expect(o).to be_captive
      end
      it "should set a quality_metric" do
        expect(o.quality_metrics).to be_blank
        patch :update, id: o.id, observation: {captive_flag: '1'}
        o.reload
        expect(o.quality_metrics).not_to be_blank
      end
    end

    describe "license changes" do
      let(:u) { User.make! }
      let(:past_o) { Observation.make!(user: u, license: nil) }
      let(:o) { Observation.make!(user: u, license: nil) }
      before do
        expect( u.preferred_observation_license ).to be_nil
        expect( past_o.license ).to be_nil
        expect( o.license ).to be_nil
        sign_in u
      end
      it "should update the license of the observation" do
        without_delay do
          put :update, id: o.id, observation: {license: Observation::CC_BY}
        end
        o.reload
        expect( o.license ).to eq Observation::CC_BY
      end
      it "should update user default" do
        without_delay do
          put :update, id: o.id, observation: {license: Observation::CC_BY, make_license_default: true}
        end
        u.reload
        expect( u.preferred_observation_license ).to eq Observation::CC_BY
      end
      it "should update past licenses" do
        without_delay do
          put :update, id: o.id, observation: {license: Observation::CC_BY, make_licenses_same: true}
        end
        past_o.reload
        expect( past_o.license ).to eq Observation::CC_BY
      end
    end
  end

  describe "show" do
    render_views
    it "should not include the place_guess when coordinates obscured" do
      original_place_guess = "Duluth, MN"
      o = Observation.make!(geoprivacy: Observation::OBSCURED, latitude: 1, longitude: 1, place_guess: original_place_guess)
      get :show, id: o.id
      expect( response.body ).not_to be =~ /#{original_place_guess}/
    end
    it "should 404 for absurdly large ids" do
      get :show, id: "389299563_507aed5ae4_s.jpg"
      expect( response ).to be_not_found
    end
  end

  describe "show.mobile" do
    render_views
    it "should now include the place_guess when coordinates obscured" do
      original_place_guess = "Duluth, MN"
      o = Observation.make!(geoprivacy: Observation::OBSCURED, latitude: 1, longitude: 1, place_guess: original_place_guess)
      get :show, format: "mobile", id: o.id
      expect( response.body ).not_to be =~ /#{original_place_guess}/
    end
  end
  
  describe "import_photos" do
    # to test this we need to mock a flickr response
    it "should import photos that are already entered as taxon photos"
  end

  describe "by_login_all", "page cache" do
    before do
      @observation = Observation.make!
      @user = @observation.user
      path = observations_by_login_all_path(@user.login, :format => 'csv')
      FileUtils.rm private_page_cache_path(path), :force => true
      sign_in @user
    end

    it "should set after request" do
      without_delay do
        get :by_login_all, :login => @user.login, :format => :csv
      end
      expect(response).to be_private_page_cached
    end

    it "should be cleared by new observations" do
      without_delay do
        get :by_login_all, :login => @user.login, :format => :csv
      end
      expect(response).to be_private_page_cached
      post :create, :observation => {:species_guess => "foo"}
      expect(observations_by_login_all_path(@user.login, :format => :csv)).to_not be_private_page_cached
    end
  end

  describe "project" do
    before(:each) { enable_elastic_indexing( Observation, UpdateAction ) }
    after(:each) { disable_elastic_indexing( Observation, UpdateAction ) }
    render_views

    describe "viewed by project curator" do
      let(:p) { Project.make! }
      let(:pu) { ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR) }
      let(:u) { pu.user }
      before do
        sign_in u
      end

      it "should include private coordinates" do
        po = make_project_observation(project: p, prefers_curator_coordinate_access: true)
        expect( po ).to be_prefers_curator_coordinate_access
        o = po.observation
        o.update_attributes(:geoprivacy => Observation::PRIVATE, :latitude => 1.23456, :longitude => 1.23456)
        o.reload
        expect( o.private_latitude ).to_not be_blank
        get :project, :id => p.id
        expect(response.body).to be =~ /#{o.private_latitude}/
      end

      it "should not include private coordinates if observer is not a member" do
        po = ProjectObservation.make!(project: p)
        o = po.observation
        o.update_attributes(:geoprivacy => Observation::PRIVATE, :latitude => 1.23456, :longitude => 1.23456)
        o.reload
        expect(o.private_latitude).to_not be_blank
        get :project, :id => p.id
        expect(response.body).not_to be =~ /#{o.private_latitude}/
      end

      it "should not include private coordinates if observer does not prefer it" do
        po = make_project_observation(preferred_curator_coordinate_access: false)
        o = po.observation
        o.update_attributes(:geoprivacy => Observation::PRIVATE, :latitude => 1.23456, :longitude => 1.23456)
        o.reload
        expect(o.private_latitude).to_not be_blank
        get :project, :id => p.id
        expect(response.body).not_to be =~ /#{o.private_latitude}/
      end
    end

    it "should not include private coordinates when viewed by a normal project member" do
      po = make_project_observation
      o = po.observation
      o.update_attributes(:geoprivacy => Observation::PRIVATE, :latitude => 1.23456, :longitude => 1.23456)
      o.reload
      expect(o.private_latitude).to_not be_blank
      p = po.project
      pu = ProjectUser.make!(:project => p)
      u = pu.user
      sign_in u
      get :project, :id => p.id
      expect(response.body).to_not be =~ /#{o.private_latitude}/
    end
  end

  describe "project_all", "page cache" do
    before do
      @project = Project.make!
      @user = @project.user
      @observation = Observation.make!(:user => @user)
      @project_observation = make_project_observation(:project => @project, :observation => @observation, :user => @observation.user)
      @observation = @project_observation.observation
      ActionController::Base.perform_caching = true
      path = all_project_observations_path(@project, :format => 'csv')
      FileUtils.rm private_page_cache_path(path), :force => true
      sign_in @user
    end

    after do
      ActionController::Base.perform_caching = false
    end

    it "should set after request" do
      without_delay do
        get :project_all, :id => @project, :format => :csv
      end
      expect(response).to be_private_page_cached
    end

    it "should be cleared by new observations" do
      without_delay do
        get :project_all, :id => @project, :format => :csv
      end
      expect(response).to be_private_page_cached
      post :destroy, :id => @observation
      expect(all_project_observations_path(@project, :format => :csv)).to_not be_private_page_cached
    end
    describe "when viewed by a project curator" do
      before do
        @project.curators << @user
        expect( @project ).to be_curated_by @user
      end
      it "should include private coordinates for observations with geoprivacy" do
        @observation.update_attributes(
          geoprivacy: Observation::PRIVATE,
          latitude: 1.2345,
          longitude: 1.2345
        )
        expect( @observation ).to be_coordinates_obscured
        expect( @project_observation ).to be_prefers_curator_coordinate_access
        get :project_all, :id => @project, :format => :csv
        target_row = nil
        CSV.parse(response.body, headers: true) do |row|
          if row['id'].to_i == @observation.id
            target_row = row
          end
        end
        expect( target_row ).not_to be_blank
        expect( target_row['private_latitude'] ).not_to be_blank
        expect( target_row['private_longitude'] ).not_to be_blank
      end

      it "should include private coordinates for observations of threatened taxa" do
        @observation.update_attributes(
          latitude: 1.2345,
          longitude: 1.2345,
          taxon: make_threatened_taxon
        )
        expect( @observation ).to be_coordinates_obscured
        expect( @project_observation ).to be_prefers_curator_coordinate_access
        get :project_all, :id => @project, :format => :csv
        target_row = nil
        CSV.parse(response.body, headers: true) do |row|
          if row['id'].to_i == @observation.id
            target_row = row
          end
        end
        expect( target_row ).not_to be_blank
        expect( target_row['private_latitude'] ).not_to be_blank
        expect( target_row['private_longitude'] ).not_to be_blank
      end
    end
  end

  describe "by_login_all" do
    it "should include observation fields" do
      of = ObservationField.make!(:name => "count", :datatype => "numeric")
      ofv = ObservationFieldValue.make!(:observation_field => of, :value => 7)
      user = ofv.observation.user
      sign_in user
      get :by_login_all, :login => user.login, :format => :csv
      expect(response.body).to be =~ /field\:count/
    end
  end

  describe "project_all", "csv" do
    it "should include observation fields" do
      of = ObservationField.make!(:name => "count", :datatype => "numeric")
      pof = ProjectObservationField.make!(:observation_field => of)
      p = pof.project
      po = make_project_observation(:project => p)
      ofv = ObservationFieldValue.make!(:observation_field => of, :value => 7, :observation => po.observation)
      sign_in p.user
      get :project_all, :id => p.id, :format => :csv
      expect(response.body).to be =~ /field\:count/
    end

    it "should have project-specific fields" do
      p = Project.make!
      sign_in p.user
      get :project_all, :id => p.id, :format => :csv
      %w(curator_ident_taxon_id curator_ident_taxon_name curator_ident_user_id curator_ident_user_login tracking_code).each do |f|
        expect(response.body).to be =~ /#{f}/
      end
    end

    it "should have private coordinates for curators" do
      po = make_project_observation
      po.observation.update_attributes(latitude: 9.8765, longitude: 4.321, geoprivacy: Observation::PRIVATE)
      p = po.project
      expect(p.user).not_to be po.observation.user
      sign_in p.user
      expect(p).to be_curated_by p.user
      get :project_all, id: p.id, format: :csv
      expect(response.body).to be =~ /private_latitude/
      expect(response.body).to be =~ /#{po.observation.private_latitude}/
      expect(response.body).to be =~ /#{po.observation.private_longitude}/
    end

    it "should not have private_coordinates when curator_coordinate_access is false" do
      o = Observation.make!(latitude: 1.2345, longitude: 1.2345, geoprivacy: Observation::OBSCURED)
      po = ProjectObservation.make!(observation: o)
      expect( po.observation ).to be_coordinates_obscured
      expect( po.project.project_users.where(user_id: po.observation.user_id) ).to be_blank
      expect( po ).not_to be_prefers_curator_coordinate_access
      sign_in po.project.user
      get :project_all, id: po.project_id, format: :csv
      expect(response.body).to be =~ /private_latitude/
      expect(response.body).not_to be =~ /#{po.observation.private_latitude}/
    end
  end
  
  describe "photo" do
    let(:file) { fixture_file_upload('files/egg.jpg', 'image/jpeg') }
    before do
      @user = User.make!
      sign_in @user
    end
    it "should generate an error if no files specified" do
      post :photo, :format => :json
      json = JSON.parse(response.body)
      expect(json['error']).to_not be_blank
    end

    it "should set the site based on config" do
      @site = Site.make!
      stub_config(site_id: @site.id)
      post :photo, :format => :json, :files => [ file ]
      expect(@user.observations.last.site).to_not be_blank
    end

    it "should set the site based on user's site" do
      @user.update_attribute(:site_id, Site.make!.id)
      post :photo, :format => :json, :files => [ file ]
      expect(@user.observations.last.site).to_not be_blank
    end

    # ugh, how to test uploads...
    it "should generate an error if single file makes invalid photo"
  end

  describe "curation" do
    render_views
    before :each do
      @curator = make_curator
      http_login(@curator)
    end

    it "should render a link to the flagger" do
      Flag.make!(user: @curator, flaggable: Observation.make!)
      get :curation
      expect(response.body).to have_selector("table td", text: @curator.login)
      expect(response.body).to_not have_selector("table td", text: Site.default.site_name_short)
    end

    it "should show site.site_name_short if there is no flagger" do
      Flag.make!(flaggable: Observation.make!)
      Flag.last.update_column(:user_id, 0)
      get :curation
      expect(response.body).to_not have_selector("table td", text: @curator.login)
      expect(response.body).to have_selector("table td", text: Site.default.site_name_short)
    end
  end

  describe "index" do
    before(:each) { enable_elastic_indexing( Observation, UpdateAction ) }
    after(:each) { disable_elastic_indexing( Observation, UpdateAction ) }
    render_views
    it "should just ignore project slugs for projects that don't exist" do
      expect {
        get :index, projects: 'imaginary-project'
      }.not_to raise_error
    end

    it "should include https image urls in widget response" do
      make_research_grade_observation
      get :index, protocol: :https, format: :widget
      expect( response.body ).to match /s3.amazonaws.com/
    end
  end

  describe "review" do
    let(:obs_to_review) { Observation.make! }
    it "forces users to log in when requesting HTML" do
      post :review, id: obs_to_review, format: :html
      expect(response.response_code).to eq 302
      expect(response).to be_redirect
      expect(response).to redirect_to(new_user_session_url)
    end
    it "denies non-logged-in users when requesting JSON" do
      post :review, id: obs_to_review, format: :json
      expect(response.response_code).to eq 401
      json = JSON.parse(response.body.to_s)
      expect(json["error"]).to eq "You need to sign in or sign up before continuing."
    end
    it "allows logged-in requests" do
      sign_in obs_to_review.user
      post :review, id: obs_to_review, format: :json
      expect(response.response_code).to eq 204
      expect(response.body).to be_blank
    end
    it "redirects HTML requests to the observations page" do
      sign_in obs_to_review.user
      post :review, id: obs_to_review, format: :html
      expect(response.response_code).to eq 302
      expect(response).to redirect_to(observation_url(obs_to_review))
    end
    it "creates an observation review if one does not exist" do
      obs_to_review.observation_reviews.destroy_all
      reviewer = User.make!
      expect(obs_to_review.observation_reviews.where(user_id: reviewer.id).size).to eq 0
      sign_in reviewer
      post :review, id: obs_to_review
      obs_to_review.reload
      expect(obs_to_review.observation_reviews.where(user_id: reviewer.id).size).to eq 1
      expect(obs_to_review.observation_reviews.first.reviewed).to eq true
      expect(obs_to_review.observation_reviews.first.user_added).to eq true
    end
    it "updates an existing observation review" do
      obs_to_review.observation_reviews.destroy_all
      reviewer = User.make!
      expect(obs_to_review.observation_reviews.where(user_id: reviewer.id).size).to eq 0
      sign_in reviewer
      post :review, id: obs_to_review
      obs_to_review.reload
      expect(obs_to_review.observation_reviews.where(user_id: reviewer.id).size).to eq 1
      expect(obs_to_review.observation_reviews.first.reviewed).to eq true
      post :review, id: obs_to_review, reviewed: "false"
      obs_to_review.reload
      expect(obs_to_review.observation_reviews.where(user_id: reviewer.id).size).to eq 1
      expect(obs_to_review.observation_reviews.first.reviewed).to eq false
    end
  end

end

describe ObservationsController, "spam" do
  let(:spammer_content) {
    o = Observation.make!
    o.user.update_attributes(spammer: true)
    o
  }
  let(:flagged_content) {
    o = Observation.make!
    Flag.make!(flaggable: o, flag: Flag::SPAM)
    o
  }

  it "should render 403 when the owner is a spammer" do
    get :show, id: spammer_content.id
    expect(response.response_code).to eq 403
  end

  it "should render 403 when content is flagged as spam" do
    get :show, id: spammer_content.id
    expect(response.response_code).to eq 403
  end
end

describe ObservationsController, "new_batch" do
  describe "routes" do
    before do
      sign_in User.make!
    end
    it "should accept GET requests" do
      expect(get: "/observations/new/batch").to be_routable
    end
    it "should accept POST requests" do
      expect(post: "/observations/new/batch").to be_routable
    end
  end
end

describe ObservationsController, "new_bulk_csv" do
  let(:work_path) { File.join(Dir::tmpdir, "new_bulk_csv-#{Time.now.to_i}.csv") }
  let(:headers) do
    %w(taxon_name date_observed description place_name latitude longitude tags geoprivacy)
  end
  let(:user) { User.make! }
  before do
    sign_in user
  end
  it "should not allow you to enqueue the same file twice" do
    Delayed::Job.delete_all
    post :new_bulk_csv, upload: {datafile: fixture_file_upload('observations.csv', 'text/csv')}
    expect( response ).to be_redirect
    expect( Delayed::Job.count ).to eq 1
    sleep(2)
    post :new_bulk_csv, upload: {datafile: fixture_file_upload('observations.csv', 'text/csv')}
    expect( Delayed::Job.count ).to eq 1
  end

  it "should allow you to enqueue different files" do
    Delayed::Job.delete_all
    CSV.open(work_path, 'w') do |csv|
      csv << headers
      csv << [
        'Homo sapiens',
        '2015-01-01',
        'Too many of them',
        'San Francisco',
        '37.7693',
        '-122.46565',
        'foo,bar',
        'open'
      ]
      csv
    end
    post :new_bulk_csv, upload: {datafile: Rack::Test::UploadedFile.new(work_path, 'text/csv')}
    expect( response ).to be_redirect
    expect( Delayed::Job.count ).to eq 1
    post :new_bulk_csv, upload: {datafile: fixture_file_upload('observations.csv', 'text/csv')}
    expect( Delayed::Job.count ).to eq 2
  end

  it "should create observations" do
    Delayed::Job.delete_all
    Observation.by( user ).destroy_all
    expect( Observation.by( user ).count ).to eq 0
    CSV.open(work_path, 'w') do |csv|
      csv << headers
      csv << [
        'Homo sapiens',
        '2015-01-01',
        'Too many of them',
        'San Francisco',
        '37.7693',
        '-122.46565',
        'foo,bar',
        'open'
      ]
      csv
    end
    Taxon.make!( name: "Homo sapiens" )
    post :new_bulk_csv, upload: {datafile: Rack::Test::UploadedFile.new(work_path, 'text/csv')}
    Delayed::Worker.new.work_off
    expect( Observation.by( user ).count ).to eq 1
  end

  it "should create observations with custom coordinate systems" do
    Site.default.update_attributes( coordinate_systems_json: '{
      "nztm2000": {
        "label": "NZTM2000 (NZ Transverse Mercator), EPSG:2193",
        "proj4": "+proj=tmerc +lat_0=0 +lon_0=173 +k=0.9996 +x_0=1600000 +y_0=10000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
      },
      "nzmg": {
        "label": "NZMG (New Zealand Map Grid), EPSG:27200",
        "proj4": "+proj=nzmg +lat_0=-41 +lon_0=173 +x_0=2510000 +y_0=6023150 +ellps=intl +datum=nzgd49 +units=m +no_defs"
      }
    }' )
    expect(Site.last.coordinate_systems).not_to be_blank
    Delayed::Job.delete_all
    Observation.by( user ).destroy_all
    expect( Observation.by( user ).count ).to eq 0
    CSV.open(work_path, 'w') do |csv|
      csv << headers
      csv << [
        'Homo sapiens',
        '2015-01-01',
        'Too many of them',
        'San Francisco',
        5635569, # these coordinates should be NZMG for Lat -39.380943828, Lon 176.3574072522
        1889191,
        'foo,bar',
        'open'
      ]
      csv
    end
    Taxon.make!( name: "Homo sapiens" )
    post :new_bulk_csv, upload: {
      datafile: Rack::Test::UploadedFile.new(work_path, 'text/csv'),
      coordinate_system: "nzmg"
    }
    Delayed::Worker.new.work_off
    expect( Observation.by( user ).count ).to eq 1
  end
end
