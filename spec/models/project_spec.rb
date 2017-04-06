require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Project do

  it "resets last_aggregated_at if start or end times changed" do
    p = Project.make!(prefers_aggregation: true, project_type: Project::BIOBLITZ_TYPE,
      place: make_place_with_geom, start_time: Time.now, end_time: Time.now)
    p.update_attributes(last_aggregated_at: Time.now)
    expect( p.last_aggregated_at ).to_not be_nil
    # change the start time
    p.update_attributes(start_time: 1.hour.ago)
    expect( p.last_aggregated_at ).to be_nil
    p.update_attributes(last_aggregated_at: Time.now)
    expect( p.last_aggregated_at ).to_not be_nil
    # change the end time
    p.update_attributes(end_time: 1.minute.ago)
    expect( p.last_aggregated_at ).to be_nil
  end

  it "removes start and end times from non-bioblitzes" do
    p = Project.make!(project_type: Project::BIOBLITZ_TYPE,
      start_time: Time.now, end_time: Time.now)
    p.update_attributes(description: "something")
    p.reload
    expect( p.start_time ).to_not be_nil
    expect( p.end_time ).to_not be_nil
    p.update_attributes(project_type: nil)
    p.reload
    expect( p.start_time ).to be_nil
    expect( p.end_time ).to be_nil
  end

  describe "creation" do
    it "should automatically add the creator as a member" do
      project = Project.make!
      expect(project.project_users).not_to be_empty
      expect(project.project_users.first.user_id).to eq project.user_id
    end

    it "should automatically add the creator as a member for invite-only projects" do
      project = Project.make!(prefers_membership_model: Project::MEMBERSHIP_INVITE_ONLY)
      expect(project.project_users).not_to be_empty
      expect(project.project_users.first.user_id).to eq project.user_id
    end
  
    it "should not allow ProjectsController action names as titles" do
      project = Project.make!
      expect(project).to be_valid
      project.title = "new"
      expect(project).not_to be_valid
      project.title = "user"
      expect(project).not_to be_valid
    end
  
    it "should stip titles" do
      project = Project.make!(:title => " zomg spaces ")
      expect(project.title).to eq 'zomg spaces'
    end

    it "should validate uniqueness of title" do
      p1 = Project.make!
      p2 = Project.make(:title => p1.title)
      expect(p2).not_to be_valid
      expect(p2.errors[:title]).not_to be_blank
    end

    it "should not notify the owner of their own new projects" do
      p = without_delay {Project.make!}
      expect(UpdateAction.where(resource: p).first).to be_blank
    end

    describe "for bioblitzes" do
      let(:p) do
        Project.make(
          project_type: Project::BIOBLITZ_TYPE, 
          place: make_place_with_geom,
          start_time: "2013-05-10T00:00:00-0800",
          end_time: "2013-05-11T23:00:00-0800"
        )
      end

      it "should parse unconventional start_time formats" do
        p.start_time = "3 days ago"
        p.end_time = "3 days ago"
        p.save
        expect( p ).to be_valid
      end

      it "should not raise an exception when start time isn't set" do
        p.start_time = "2:00 p.m. 4/24/15"
        p.end_time = "2:00 p.m. 4/25/15"
        expect( Chronic.parse(p.start_time) ).to be_nil
        expect { p.save }.not_to raise_error
        expect( p ).not_to be_valid
      end

      it "should not allow comma-separated event URLs" do
        expect( p ).to be_valid
        p.event_url = "http://bioblitz-birding.eventbrite.com, http://bioblitz-plants.eventbrite.com, http://bioblitz-ecosystems.eventbrite.com"
        expect( p ).not_to be_valid
      end
    end

  end

  describe "destruction" do
    it "should work despite rule against owner leaving the project" do
      project = Project.make!
      expect{ project.destroy }.to_not raise_error
    end

    it "should delete project observations" do
      po = make_project_observation
      p = po.project
      po.reload
      p.destroy
      expect(ProjectObservation.find_by_id(po.id)).to be_blank
    end
  end

  describe "update_curator_idents_on_make_curator" do
    before(:each) do
      @project_user = ProjectUser.make!
      @project = @project_user.project
      @observation = Observation.make!(:user => @project_user.user)
    end
  
    it "should set curator_identification_id on existing project observations" do
      po = ProjectObservation.make!(:project => @project, :observation => @observation)
      c = ProjectUser.make!(:project => @project, :role => ProjectUser::CURATOR)
      expect(po.curator_identification_id).to be_blank
      ident = Identification.make!(:user => c.user, :observation => po.observation)
      Project.update_curator_idents_on_make_curator(@project.id, c.id)
      po.reload
      expect(po.curator_identification_id).to eq ident.id
    end
  end

  describe "update_curator_idents_on_remove_curator" do
    before(:each) do
      @project = Project.make!
      @project_user = ProjectUser.make!(:project => @project)
      @observation = Observation.make!(:user => @project_user.user)
      @project_observation = ProjectObservation.make!(:project => @project, :observation => @observation)
      @project_user_curator = ProjectUser.make!(:project => @project, :role => ProjectUser::CURATOR)
      Identification.make!(:user => @project_user_curator.user, :observation => @project_observation.observation)
      Project.update_curator_idents_on_make_curator(@project.id, @project_user_curator.id)
      @project_observation.reload
    end
  
    it "should remove curator_identification_id on existing project observations if no other curator idents" do
      @project_user_curator.update_attributes(:role => nil)
      Project.update_curator_idents_on_remove_curator(@project.id, @project_user_curator.user_id)
      @project_observation.reload
      expect(@project_observation.curator_identification_id).to be_blank
    end
  
    it "should reset curator_identification_id on existing project observations if other curator idents" do
      pu = ProjectUser.make!(:project => @project, :role => ProjectUser::CURATOR)
      ident = Identification.make!(:observation => @project_observation.observation, :user => pu.user)
    
      @project_user_curator.update_attributes(:role => nil)
      Project.update_curator_idents_on_remove_curator(@project.id, @project_user_curator.user_id)
    
      @project_observation.reload
      expect(@project_observation.curator_identification_id).to eq ident.id
    end
  
    it "should work for deleted users" do
      user_id = @project_user_curator.user_id
      @project_user_curator.user.destroy
      Project.update_curator_idents_on_remove_curator(@project.id, user_id)
      @project_observation.reload
      expect(@project_observation.curator_identification_id).to be_blank
    end
  end

  describe "eventbrite_id" do
    it "should parse a variety of URLS" do
      id = "12345"
      [
        "http://www.eventbrite.com/e/memorial-park-bioblitz-2014-tickets-#{id}",
        "http://www.eventbrite.com/e/#{id}"
      ].each do |url|
        p = Project.make(:event_url => url)
        expect(p.eventbrite_id).to eq id
      end
    end
    it "should not bail if no id" do
      expect {
        Project.make(:event_url => "http://www.eventbrite.com").eventbrite_id
      }.not_to raise_error
    end
  end

  describe "icon_url" do
    let(:p) { Project.make! }
    before do
      allow(p).to receive(:icon_file_name) { "foo.png" }
      allow(p).to receive(:icon_content_type) { "image/png" }
      allow(p).to receive(:icon_file_size) { 12345 }
      allow(p).to receive(:icon_updated_at) { Time.now }
      expect(p.icon_url).not_to be_blank
    end
    it "should be absolute" do
      expect(p.icon_url).to match /^http/
    end
    it "should not have two protocols" do
      expect(p.icon_url.scan(/http/).size).to eq 1
    end
  end

  describe "range_by_date" do
    it "should be false by default" do
      expect(Project.make!).not_to be_prefers_range_by_date
    end
    describe "date boundary" do
      let(:place) { make_place_with_geom }
      let(:project) {
        Project.make!(
          project_type: Project::BIOBLITZ_TYPE, 
          start_time: '2014-05-14T21:08:00-07:00', 
          end_time: '2014-05-25T20:59:00-07:00',
          place: place,
          prefers_range_by_date: true
        )
      }
      it "should include observations observed outside the time boundary by inside the date boundary" do
        expect(project).to be_prefers_range_by_date
        o = Observation.make!(latitude: place.latitude, longitude: place.longitude, observed_on_string: '2014-05-14T21:06:00-07:00')
        expect(Observation.query(project.observations_url_params).to_a).to include o
      end
      it "should exclude observations on the outside" do
        o = Observation.make!(latitude: place.latitude, longitude: place.longitude, observed_on_string: '2014-05-13T21:06:00-07:00')
        expect(Observation.query(project.observations_url_params).to_a).not_to include o
      end
    end
  end

  describe "generate_csv" do
    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }
    it "should include curator_coordinate_access" do
      path = File.join(Dir::tmpdir, "project_generate_csv_test-#{Time.now.to_i}")
      po = make_project_observation
      po.project.generate_csv(path, Observation::CSV_COLUMNS)
      CSV.foreach(path, headers: true) do |row|
        expect(row['curator_coordinate_access']).not_to be_blank
      end
    end
    it "curator_coordinate_access should be false by default for non-members" do
      path = File.join(Dir::tmpdir, "project_generate_csv_test-#{Time.now.to_i}")
      po = ProjectObservation.make!
      po.project.generate_csv(path, Observation::CSV_COLUMNS)
      CSV.foreach(path, headers: true) do |row|
        expect(row['curator_coordinate_access']).to eq "false"
      end
    end
    it "should include captive_cultivated" do
      path = File.join(Dir::tmpdir, "project_generate_csv_test-#{Time.now.to_i}")
      po = make_project_observation
      po.project.generate_csv(path, Observation::CSV_COLUMNS)
      CSV.foreach(path, headers: true) do |row|
        expect(row['captive_cultivated']).not_to be_blank
      end
    end
    it "should include coordinates_obscured" do
      path = File.join( Dir::tmpdir, "project_generate_csv_test-#{Time.now.to_i}" )
      o = make_research_grade_observation( geoprivacy: Observation::OBSCURED )
      po = make_project_observation( observation: o )
      po.project.generate_csv( path, Observation::CSV_COLUMNS )
      CSV.foreach( path, headers: true ) do |row|
        expect( row["coordinates_obscured"] ).to eq "true"
      end
    end
  end

  describe "aggregation preference" do
    it "should be false by default" do
      expect( Project.make! ).not_to be_prefers_aggregation
    end

    it "should cause a validation error if aggregation is not allowed" do
      p = Project.make!
      expect( p ).not_to be_aggregation_allowed
      p.prefers_aggregation = true
      expect( p ).not_to be_valid
    end
  end

  describe "aggregate_observations class method" do
    before(:each) { enable_elastic_indexing(Observation, Place) }
    after(:each) { disable_elastic_indexing(Observation, Place) }
    it "should touch projects that prefer aggregation" do
      p = Project.make!(prefers_aggregation: true, place: make_place_with_geom, trusted: true)
      expect( p.last_aggregated_at ).to be_nil
      Project.aggregate_observations
      p.reload
      expect( p.last_aggregated_at ).not_to be_nil
    end

    it "should not touch projects that do not prefer aggregation" do
      p = Project.make!(prefers_aggregation: false, place: make_place_with_geom, trusted: true)
      expect( p.last_aggregated_at ).to be_nil
      Project.aggregate_observations
      p.reload
      expect( p.last_aggregated_at ).to be_nil
    end
  end

  describe "aggregate_observations" do
    before(:each) { enable_elastic_indexing(Observation, Place) }
    after(:each) { disable_elastic_indexing(Observation, Place) }
    let(:project) { Project.make! }
    it "should add observations matching the project observation scope" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
      project.aggregate_observations
      o.reload
      expect( o.projects ).to include project
    end

    it "should set last_aggregated_at" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      expect( project.last_aggregated_at ).to be_nil
      project.aggregate_observations
      expect( project.last_aggregated_at ).not_to be_nil
    end

    it "should not add observations not matching the project observation scope" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o = Observation.make!(latitude: project.place.latitude*-1, longitude: project.place.longitude*-1)
      project.aggregate_observations
      o.reload
      expect( o.projects ).not_to include project
    end

    it "should not happen if aggregation is not allowed" do
      expect( project ).not_to be_aggregation_allowed
      o = Observation.make!(latitude: 1, longitude: 1)
      project.aggregate_observations
      o.reload
      expect( o.projects ).not_to include project
    end

    it "should not add observation if observer has opted out" do
      u = User.make!(preferred_project_addition_by: User::PROJECT_ADDITION_BY_NONE)
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude, user: u)
      project.aggregate_observations
      o.reload
      expect( o.projects ).not_to include project
    end

    it "should not add observation if observer has not joined and prefers not to allow addition for projects not joined" do
      u = User.make!(preferred_project_addition_by: User::PROJECT_ADDITION_BY_JOINED)
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude, user: u)
      project.aggregate_observations
      o.reload
      expect( o.projects ).not_to include project
    end

    it "should add observations created since last_aggregated_at" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o1 = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
      project.aggregate_observations
      expect( project.observations.count ).to eq 1
      o2 = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
      project.aggregate_observations
      expect( project.observations.count ).to eq 2
    end

    it "should not add duplicates" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
      project.aggregate_observations
      project.aggregate_observations
      o.reload
      expect( o.projects ).to include project
      expect( o.project_observations.size ).to eq 1
    end

    it "adds observations whose users were updated since last_aggregated_at" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o1 = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
      o2 = Observation.make!(latitude: 90, longitude: 90)
      project.aggregate_observations
      expect( project.observations.count ).to eq 1
      o2.update_attributes(latitude: project.place.latitude, longitude: project.place.longitude)
      o2.update_columns(updated_at: 1.day.ago)
      o2.elastic_index!
      project.aggregate_observations
      # it's still 1 becuase the observations was updated in the past
      expect( project.observations.count ).to eq 1
      o2.user.update_columns(updated_at: Time.now)
      project.aggregate_observations
      # now the observation was aggregated because the user was updated
      expect( project.observations.count ).to eq 2
    end

    it "adds observations whose ProjectUsers were updated since last_aggregated_at" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
      pu = ProjectUser.make!(project: project, user: o.user)
      project.aggregate_observations
      expect( project.observations.count ).to eq 1
      ProjectObservation.delete_all
      o.update_columns(updated_at: 1.day.ago)
      o.elastic_index!
      project.aggregate_observations
      # the observation was updated BEFORE the last aggregation
      expect( project.observations.count ).to eq 0
      pu.touch
      project.aggregate_observations
      # the ProjectUser and User were updated AFTER the last aggregation
      expect( project.observations.count ).to eq 1
    end

    it "updates project_users' observations and taxa counts" do
      project.update_attributes(place: make_place_with_geom, trusted: true)
      pu = ProjectUser.make!(project: project)
      taxon = Taxon.make!(rank: "species")
      Observation.make!(latitude: project.place.latitude,
        longitude: project.place.longitude, user: pu.user, taxon: taxon)
      Observation.make!(latitude: project.place.latitude,
        longitude: project.place.longitude, user: pu.user, taxon: taxon)
      expect( pu.observations_count ).to eq 0
      expect( pu.taxa_count ).to eq 0
      expect( project.observations.count ).to eq 0
      project.aggregate_observations
      project.reload
      pu.reload
      expect( project.observations.count ).to eq 2
      expect( pu.observations_count ).to eq 2
      expect( pu.taxa_count ).to eq 1
    end
  end

  describe "aggregation_allowed?" do
    it "is false by default" do
      expect( Project.make! ).not_to be_aggregation_allowed
    end

    it "is true if place smaller than Texas" do
      p = Project.make!(place: make_place_with_geom, trusted: true)
      expect( p ).to be_aggregation_allowed
    end

    it "is false if place bigger than Texas" do
      envelope_ewkt = "MULTIPOLYGON(((0 0,0 15,15 15,15 0,0 0)))"
      p = Project.make!(place: make_place_with_geom(ewkt: envelope_ewkt), trusted: true)
      expect( p ).not_to be_aggregation_allowed
    end

    it "should be true with a taxon rule" do
      p = Project.make!(trusted: true)
      por = ProjectObservationRule.make!(operator: 'in_taxon?', operand: Taxon.make!, ruler: p)
      expect( por.ruler ).to be_aggregation_allowed
    end

    it "should be true with multiple taxon rules" do
      p = Project.make!(trusted: true)
      por1 = ProjectObservationRule.make!(operator: 'in_taxon?', operand: Taxon.make!, ruler: p)
      por2 = ProjectObservationRule.make!(operator: 'in_taxon?', operand: Taxon.make!, ruler: p)
      expect( por1.ruler ).to be_aggregation_allowed
    end

    it "should be true with a list rule" do
      p = Project.make!(trusted: true)
      por = ProjectObservationRule.make!(operator: 'on_list?', ruler: p)
      expect( por.ruler ).to be_aggregation_allowed
    end
  end

  describe "slug" do
    it "should change when the title changes" do
      p = Project.make!(title: "The Title")
      expect( p.slug ).to eq 'the-title'
      p.update_attributes(title: 'The BEST Title')
      p.reload
      expect( p.title ).to eq 'The BEST Title'
      expect( p.slug ).to eq 'the-best-title'
    end
  end

  describe "preferred_submission_model" do
    it "should allow observations submitted by anybody when set to any" do
      p = Project.make!(preferred_submission_model: Project::SUBMISSION_BY_ANYONE)
      po = ProjectObservation.make!(project: p)
      expect( po ).to be_valid
    end
    it "should allow observations submitted by curators when set to curators" do
      p = Project.make!(preferred_submission_model: Project::SUBMISSION_BY_CURATORS)
      po = ProjectObservation.make!(project: p, user: p.user)
      expect( po ).to be_valid
    end
    it "should allow observations with no submitter when set to curators" do
      p = Project.make!(preferred_submission_model: Project::SUBMISSION_BY_CURATORS)
      po = ProjectObservation.make!(project: p)
      expect( po ).to be_valid
    end
    it "should not allow observations submitted by non-curators when set to curators" do
      p = Project.make!(preferred_submission_model: Project::SUBMISSION_BY_CURATORS)
      pu = ProjectUser.make!(project: p)
      po = ProjectObservation.make(project: p, user: pu.user)
      expect( po ).not_to be_valid
      po.save
      expect( po ).not_to be_persisted
    end
  end

  describe "update_counts" do
    before :each do
      enable_elastic_indexing(Observation)
      @p = Project.make!(preferred_submission_model: Project::SUBMISSION_BY_ANYONE)
      @pu = ProjectUser.make!(project: @p)
      taxon = Taxon.make!(rank: "species")
      5.times do
        ProjectObservation.make!(project: @p, user: @pu.user,
          observation: Observation.make!(taxon: taxon, user: @pu.user))
      end
      taxon = Taxon.make!(rank: "species")
      4.times do
        ProjectObservation.make!(project: @p, user: @pu.user,
          observation: Observation.make!(taxon: taxon, user: @pu.user))
      end
    end
    after(:each) { disable_elastic_indexing(Observation) }

    it "should update counts for all project_users in a project" do
      expect( @pu.observations_count ).to eq 0
      expect( @pu.taxa_count ).to eq 0
      @p.update_counts
      @pu.reload
      expect( @pu.observations_count ).to eq 9
      expect( @pu.taxa_count ).to eq 2
    end
  end

  describe "sane_destroy" do
    it "should delete the project" do
      p = Project.make!
      3.times { ProjectObservation.make!( project: p ) }
      3.times { ProjectUser.make!( project: p ) }
      p.sane_destroy
      expect( Project.find_by_id( p.id ) ).to be_blank
    end
  end
end
