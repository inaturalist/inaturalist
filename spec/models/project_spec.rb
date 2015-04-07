require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Project, "creation" do
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

  it "should notify the owner that the admin changed" do
    p = without_delay {Project.make!}
    expect(Update.where(:resource_type => "Project", :resource_id => p.id, :subscriber_id => p.user_id).first).to be_blank
  end
end

describe Project, "destruction" do
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

describe Project, "update_curator_idents_on_make_curator" do
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

describe Project, "update_curator_idents_on_remove_curator" do
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

describe Project, "eventbrite_id" do
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
end

describe Project, "icon_url" do
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

describe Project, "range_by_date" do
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

describe Project, "generate_csv" do
  it "should include usage_according_to_terms" do
    path = File.join(Dir::tmpdir, "project_generate_csv_test-#{Time.now.to_i}")
    po = make_project_observation
    po.project.generate_csv(path, Observation::CSV_COLUMNS)
    CSV.foreach(path, headers: true) do |row|
      expect(row['usage_according_to_terms']).not_to be_blank
    end
  end
  it "usage_according_to_terms should be false by default for non-members" do
    path = File.join(Dir::tmpdir, "project_generate_csv_test-#{Time.now.to_i}")
    po = ProjectObservation.make!
    po.project.generate_csv(path, Observation::CSV_COLUMNS)
    CSV.foreach(path, headers: true) do |row|
      expect(row['usage_according_to_terms']).to eq "false"
    end
  end
end

describe Project, "aggregation preference" do
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

describe Project, "aggregate_observations class method" do
  it "should touch projects that prefer aggregation" do
    p = log_timer { Project.make!(prefers_aggregation: true, place: make_place_with_geom) }
    expect( p.last_aggregated_at ).to be_nil
    Project.aggregate_observations
    p.reload
    expect( p.last_aggregated_at ).not_to be_nil
  end

  it "should not touch projects that do not prefer aggregation" do
    p = Project.make!(prefers_aggregation: false, place: make_place_with_geom)
    expect( p.last_aggregated_at ).to be_nil
    Project.aggregate_observations
    p.reload
    expect( p.last_aggregated_at ).to be_nil
  end
end

describe Project, "aggregate_observations" do
  let(:project) { Project.make! }
  it "should add observations matching the project observation scope" do
    project.update_attributes(place: make_place_with_geom)
    o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
    project.aggregate_observations
    o.reload
    expect( o.projects ).to include project
  end

  it "should set last_aggregated_at" do
    project.update_attributes(place: make_place_with_geom)
    expect( project.last_aggregated_at ).to be_nil
    project.aggregate_observations
    expect( project.last_aggregated_at ).not_to be_nil
  end

  it "should not add observations not matching the project observation scope" do
    project.update_attributes(place: make_place_with_geom)
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
    project.update_attributes(place: make_place_with_geom)
    o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude, user: u)
    project.aggregate_observations
    o.reload
    expect( o.projects ).not_to include project
  end

  it "should not add observation if observer has not joined and prefers not to allow addition for projects not joined" do
    u = User.make!(preferred_project_addition_by: User::PROJECT_ADDITION_BY_JOINED)
    project.update_attributes(place: make_place_with_geom)
    o = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude, user: u)
    project.aggregate_observations
    o.reload
    expect( o.projects ).not_to include project
  end

  it "should add observations created since last_aggregated_at" do
    project.update_attributes(place: make_place_with_geom)
    o1 = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
    project.aggregate_observations
    expect( project.observations.count ).to eq 1
    o2 = Observation.make!(latitude: project.place.latitude, longitude: project.place.longitude)
    project.aggregate_observations
    expect( project.observations.count ).to eq 2
  end
end

describe Project, "aggregation_allowed?" do
  it "is false by default" do
    expect( Project.make! ).not_to be_aggregation_allowed
  end

  it "is true if place smaller than Texas" do
    p = Project.make!(place: make_place_with_geom)
    expect( p ).to be_aggregation_allowed
  end

  it "is false if place bigger than Texas" do
    envelope_ewkt = "MULTIPOLYGON(((0 0,0 15,15 15,15 0,0 0)))"
    p = Project.make!(place: make_place_with_geom(ewkt: envelope_ewkt))
    expect( p ).not_to be_aggregation_allowed
  end

  it "should be true with a taxon rule" do
    por = ProjectObservationRule.make!(operator: 'in_taxon?', operand: Taxon.make!)
    expect( por.ruler ).to be_aggregation_allowed
  end

  it "should be true with multiple taxon rules" do
    por1 = ProjectObservationRule.make!(operator: 'in_taxon?', operand: Taxon.make!)
    por2 = ProjectObservationRule.make!(operator: 'in_taxon?', operand: Taxon.make!, ruler: por1.ruler)
    expect( por1.ruler ).to be_aggregation_allowed
  end

  it "should be true with a list rule" do
    por = ProjectObservationRule.make!(operator: 'on_list?')
    expect( por.ruler ).to be_aggregation_allowed
  end
end
