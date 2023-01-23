require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservation do
  it { is_expected.to belong_to :project }
  it { is_expected.to belong_to(:curator_identification).class_name "Identification" }
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :project }
  it { is_expected.to validate_presence_of :observation }

  describe '#georeferenced?' do
    subject { build :project_observation }

    it 'should work' do
      subject.observation.assign_attributes latitude: 0.5, longitude: 0.5
      expect(subject).to be_georeferenced
    end

    it 'should be true if observation coordinates are private' do
      subject.observation.assign_attributes latitude: 0.5, longitude: 0.5, geoprivacy: Observation::PRIVATE
      expect(subject).to be_georeferenced
    end
  end

  describe 'has photos and sounds' do
    let(:observation) { build :observation }
    let(:project) { build :project }
    let(:project_user) { build :project_user, project: project, user: observation.user }
    subject { build :project_observation, project: project, observation: observation, user: observation.user }

    before {
      allow(observation.observation_photos).to receive(:count).and_return observation.observation_photos.length
      allow(observation.observation_sounds).to receive(:count).and_return observation.observation_sounds.length
      allow(observation).to receive(:reload).and_return true
    }

    describe '#has_a_photo?' do
      context 'with photo present' do
        let(:observation) { build :observation, :research_grade, :with_photos }
        it { expect(subject.has_a_photo?).to be true }
      end

      context 'with photo not present' do
        it { expect(subject.has_a_photo?).to be false }
      end
    end

    describe '#has_a_sound?' do
      context 'with sound present' do
        let(:observation) { build :observation, :research_grade, :with_sounds }
        it { expect(subject.has_a_sound?).to be true }
      end
      context 'with sound not present' do
        it { expect(subject.has_a_sound?).to be false }
      end
    end

    describe '#has_media?' do
      context 'with photo present' do
        let(:observation) { build :observation, :research_grade, :with_photos }
        it { expect(subject.has_media?).to be true }
      end
      context 'with sound present' do
        let(:observation) { build :observation, :research_grade, :with_sounds }
        it { expect(subject.has_media?).to be true }
      end
      context 'with photo and sound not present' do
        it { expect(subject.has_media?).to_not be true }
      end
    end
  end

  describe '#identified?' do
    subject { build_stubbed :project_observation, observation: build_stubbed(:observation, taxon: nil) }
    it 'should work' do
      expect(subject).not_to be_identified
      subject.observation.assign_attributes taxon: build_stubbed(:taxon), editing_user_id: subject.observation.user_id
      expect(subject).to be_identified
    end
  end

  describe '#in_taxon?' do
    let(:project_user) { build :project_user }
    let(:project) { project_user.project }
    let(:taxon) { build :taxon, :as_species }
    let(:observation) { build :observation, user: project_user.user, taxon: taxon }

    subject { build :project_observation, observation: observation, project: project, user: observation.user }

    context 'for observations of target taxon' do
      it { is_expected.to be_in_taxon(observation.taxon) }
    end

    context 'when taxon is blank' do
      let(:observation) { build :observation, user: project_user.user, taxon: nil }

      it { is_expected.not_to be_in_taxon(nil) }
    end

    context 'for observations of descendants if target taxon' do
      let(:child) { build :taxon, :as_subspecies, parent: observation.taxon }
      let(:child_obs) { build :observation, taxon: child, user: project_user.user }
      subject { build :project_observation, observation: child_obs, project: project, user: child_obs.user }

      it { is_expected.to be_in_taxon(observation.taxon) }
    end

    context 'for observations outside of target taxon' do
      before { setup_project_and_user }
      let(:other) { create :taxon }
      let(:other_obs) { create :observation, taxon: other, user: @project_user.user }
      subject { build :project_observation, observation: other_obs, project: @project, user: other_obs.user }

      it { is_expected.not_to be_in_taxon @taxon }
    end
  end

  describe '#project_allows_observations?' do
    subject { build_stubbed :project_observation, project: project }
    context 'for collection project' do
      let(:project) { build :project, project_type: 'collection' }

      it { is_expected.to_not be_valid }
    end

    context 'for umbrella project' do
      let(:project) { build :project, project_type: 'umbrella' }

      it { is_expected.to_not be_valid }
    end
  end

  describe '#observed_in_bioblitz_time_range?' do
    subject { build :project_observation, observation: observation, project: project }

    let(:start_time) { Time.parse "2016-01-01T20:00:00-07:00" }
    let(:end_time) { Time.parse "2016-01-01T20:00:00-07:00" }
    let(:observed_on) { start_time.to_s }
    let(:observation) { build :observation, observed_on_string: observed_on }
    let(:prefers_range_by_date) { true }
    let(:project) {
      build :project,
            project_type: Project::BIOBLITZ_TYPE,
            start_time: start_time,
            end_time: end_time,
            prefers_range_by_date: prefers_range_by_date
    }

    it 'validates observed in bioblitz time range' do
      expect(subject).to receive(:observed_in_bioblitz_time_range?)

      subject.valid?
    end

    context 'project prefers range by time' do
      let(:prefers_range_by_date) { false }

      before { subject.observation.run_callbacks :validation }

      context 'equal to start time' do
        let(:observed_on) { start_time.to_s }

        it { is_expected.to be_valid }
      end
      context 'equal to end time' do
        let(:observed_on) { end_time.to_s }

        it { is_expected.to be_valid }
      end
      context 'equal to one minute earlier' do
        let(:observed_on) { (start_time - 1.minute).to_s }

        it { is_expected.to_not be_valid }
      end
      context 'equal to one minute later' do
        let(:observed_on) { (end_time + 1.minute).to_s }

        it { is_expected.to_not be_valid }
      end
    end

    context 'project prefers range by date'do
      before { subject.observation.run_callbacks :validation }

      context 'equal to start time' do
        let(:observed_on) { start_time.to_s }

        it { is_expected.to be_valid }
      end
      context 'equal to end time' do
        let(:observed_on) { end_time.to_s }

        it { is_expected.to be_valid }
      end
      context 'equal to one minute earlier' do
        let(:observed_on) { (start_time - 1.minute).to_s }

        it { is_expected.to be_valid }
      end
      context 'equal to one minute later' do
        let(:observed_on) { (end_time + 1.minute).to_s }

        it { is_expected.to be_valid }
      end
      context 'equal to one day earlier' do
        let(:observed_on) { (start_time - 1.day).to_s }

        it { is_expected.to_not be_valid }
      end
      context 'equal to one day later' do
        let(:observed_on) { (end_time + 1.day).to_s }

        it { is_expected.to_not be_valid }
      end
    end
  end

  describe '#set_curator_coordinate_access' do
    subject { build :project_observation }
    let(:access) { ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER }
    let(:observation) { build_stubbed :observation, user: project_user.user }
    let(:project_user) { build_stubbed :project_user, preferred_curator_coordinate_access: access }
    let(:project) { project_user.project }
    let(:user) { project_user.user }

    it 'sets curator coordinate access before validation' do
      expect(subject).to receive(:set_curator_coordinate_access)
      subject.valid?
    end

    context 'with no user' do
      before { subject.run_callbacks :validation }

      it 'should set curator_coordinate_access to false' do
        expect(subject.prefers_curator_coordinate_access).to be false
      end
    end

    context 'preferring access for their own additions' do
      let(:subject) { build_stubbed :project_observation, project: project, observation: observation, user: user }
      before do
        allow(subject).to receive(:project_user).and_return project_user
        subject.run_callbacks :validation
      end

      it 'should set curator_coordinate_access to true' do
        expect(subject.preferred_curator_coordinate_access).to be true
      end
    end

    context 'preferring access for their own additions and added by someone else' do
      let(:subject) { build_stubbed :project_observation, project: project, observation: observation }

      before { subject.run_callbacks :validation }

      it 'should set curator_coordinate_access to false' do
        expect(subject.preferred_curator_coordinate_access).to be false
      end
    end

    context 'preferring access for addition by others' do
      let(:subject) { build_stubbed :project_observation, project: project, observation: observation }
      let(:access) { ProjectUser::CURATOR_COORDINATE_ACCESS_ANY }

      before do
        allow(subject).to receive(:project_user).and_return project_user
        subject.run_callbacks :validation
      end

      it 'should set curator_coordinate_access to true' do
        expect(subject.preferred_curator_coordinate_access).to be true
      end
    end
  end
end

describe ProjectObservation, "creation" do
  elastic_models( Observation, Place )
  before(:each) { |example| setup_project_and_user if example.metadata[:with_setup] }

  let(:project_user) { build_stubbed :project_user }
  let(:project) { project_user.project }
  let(:taxon) { build_stubbed :taxon, :as_species }
  let(:observation) { build_stubbed :observation, user: project_user.user, taxon: taxon }

  subject { build_stubbed :project_observation, project: project, observation: observation, user: observation.user }

  it "should queue a DJ job to set project user counters" do
    stamp = Time.now
    subject.run_callbacks :create
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /\:update_observations_counter_cache/}).not_to be_blank
    expect(jobs.select{|j| j.handler =~ /\:update_taxa_counter_cache/}).not_to be_blank
  end

  it "should set curator id if observer is a curator", :with_setup do
    o = Observation.make!(:user => @project.user, :taxon => Taxon.make!)
    po = without_delay {make_project_observation(:observation => o, :project => @project, :user => o.user)}
    expect(po.curator_identification_id).to eq(o.owners_identification.id)
  end

  it "should set curator ID if observer is not a curator but a curator has identified the observation", :with_setup do
    o = Observation.make!
    i = Identification.make!( observation: o, user: @project.user )
    expect( @project ).to be_curated_by i.user
    expect( i.project_observations.count ).to eq 0
    po = without_delay { make_project_observation( observation: o, project: @project ) }
    i.reload
    expect( i.project_observations.first ).to eq po
  end

  it "should touch the observation"  do
    subject.run_callbacks :create

    expect(subject.observation.updated_at).to be > subject.observation.created_at
  end

  it "should properly touch objects that had projects preloaded", :with_setup do
    o = Observation.make!(:user => @project_user.user)
    Observation.preload_associations(o, :project_observations)
    expect(Observation.elastic_search(where: { id: o.id }).
      results.results.first.project_ids).to eq [ ]
    o.project_observations.create(project: @project)
    expect(Observation.elastic_search(where: { id: o.id }).
      results.results.first.project_ids).to eq [ @project.id ]
  end

  it "should be possible for any member of the project" do
    expect(build(:project_observation, user: project_user.user, project: project_user.project)).to be_valid
  end

  describe "updates" do
    let(:project_user) { build_stubbed :project_user, role: ProjectUser::CURATOR }
    let(:user) { project_user.user }
    let(:project) { project_user.project }
    let(:observer) { build_stubbed :user }

    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "should be generated for the observer" do
      po = without_delay { ProjectObservation.make!(user: user, project: project) }
      expect( UpdateAction.unviewed_by_user_from_query(po.observation.user_id, notifier: po) ).to eq true
    end
    it "should not be generated if the observer added to the project" do
      without_delay do
        o = Observation.make!
        p = Project.make!
        expect {
          ProjectObservation.make!(observation: o, user: o.user, project: p)
        }.not_to change(UpdateAction, :count)
      end
    end
    it "should generate updates on the project" do
      po = without_delay { ProjectObservation.make!(user: user, project: project) }
      expect( UpdateAction.last.resource ).to eq po.project
    end

    it "should not generate more than 15 updates" do
      without_delay do
        16.times do
          build_stubbed(
            :project_observation,
            user: user,
            project: project,
            observation: build_stubbed(:observation, user: observer)
          ).notify_observer(:observation)
        end
      end
      es_response = UpdateAction.elastic_search(
        filters: [
          { term: { subscriber_ids: observer.id } },
          { term: { notification: UpdateAction::YOUR_OBSERVATIONS_ADDED } }
        ]
      ).per_page(100).page(1)
      expect( es_response.results.total ).to eq 15
    end
  end

  it "should allow observations that have one not-required field but not another" do
    proj = Project.make!
    pof1 = ProjectObservationField.make!( project: proj )
    pof2 = ProjectObservationField.make!( project: proj )
    obs_with_1 = ObservationFieldValue.make!( observation_field: pof1.observation_field ).observation
    obs_with_1.reload
    obs_with_2 = ObservationFieldValue.make!( observation_field: pof2.observation_field ).observation
    obs_with_2.reload
    obs_with_1_and_2 = ObservationFieldValue.make!( observation_field: pof1.observation_field ).observation
    ObservationFieldValue.make!( observation_field: pof2.observation_field, observation: obs_with_1_and_2 )
    obs_with_1_and_2.reload
    obs_without_1_and_2 = Observation.make!

    expect( ProjectObservation.make( project: proj, observation: obs_with_1 ) ).to be_valid
    expect( ProjectObservation.make( project: proj, observation: obs_with_2 ) ).to be_valid
    expect( ProjectObservation.make( project: proj, observation: obs_with_1_and_2 ) ).to be_valid
    expect( ProjectObservation.make( project: proj, observation: obs_without_1_and_2 ) ).to be_valid
  end

  it "should not allow observations that have one required field but not another" do
    proj = Project.make!
    pof1 = ProjectObservationField.make!( project: proj, required: true )
    pof2 = ProjectObservationField.make!( project: proj, required: true )
    obs_with_1 = ObservationFieldValue.make!( observation_field: pof1.observation_field ).observation
    obs_with_1.reload
    obs_with_2 = ObservationFieldValue.make!( observation_field: pof2.observation_field ).observation
    obs_with_2.reload
    obs_with_1_and_2 = ObservationFieldValue.make!( observation_field: pof1.observation_field ).observation
    ObservationFieldValue.make!( observation_field: pof2.observation_field, observation: obs_with_1_and_2 )
    obs_with_1_and_2.reload
    obs_without_1_and_2 = Observation.make!
    proj.reload

    expect( ProjectObservation.make( project: proj, observation: obs_with_1 ) ).not_to be_valid
    expect( ProjectObservation.make( project: proj, observation: obs_with_2 ) ).not_to be_valid
    expect( ProjectObservation.make( project: proj, observation: obs_with_1_and_2 ) ).to be_valid
    expect( ProjectObservation.make( project: proj, observation: obs_without_1_and_2 ) ).not_to be_valid
  end
end

describe ProjectObservation, "destruction" do
  elastic_models( Observation, Place )
  before(:each) do
    setup_project_and_user
    @project_observation = make_project_observation(:observation => @observation, :project => @project, :user => @observation.user)
    Delayed::Job.destroy_all
    enable_has_subscribers
  end
  after(:each) {
    disable_has_subscribers
  }

  it "should not queue a DJ job for the list" do
    stamp = Time.now
    @project_observation.destroy
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /\:refresh_project_list\n/}).to be_blank
  end
  
  it "should queue a DJ job to set project user counters" do
    stamp = Time.now
    @project_observation.destroy
    jobs = Delayed::Job.where("created_at >= ?", stamp)
    expect(jobs.select{|j| j.handler =~ /\:update_observations_counter_cache/}).not_to be_blank
    expect(jobs.select{|j| j.handler =~ /\:update_taxa_counter_cache/}).not_to be_blank
  end

  it "should touch the observation" do
    o = @project_observation.observation
    t = o.updated_at
    @project_observation.destroy
    o.reload
    expect(o.updated_at).to be > t
  end

  it "should delete associated updates" do
    pu = ProjectUser.make!(role: ProjectUser::CURATOR)
    po = without_delay { ProjectObservation.make!(user: pu.user, project: pu.project) }
    expect( UpdateAction.where(notifier: po).count ).to eq 1
    po.destroy
    expect( UpdateAction.where(notifier: po).count ).to eq 0
  end
end

describe ProjectObservation, "observed_in_place_bounding_box?" do
  
  it "should work" do
    setup_project_and_user
    place = make_place_with_geom(:latitude => 0, :longitude => 0, :swlat => -1, :swlng => -1, :nelat => 1, :nelng => 1)
    @observation.update(:latitude => 0.5, :longitude => 0.5)
    project_observation = make_project_observation(:observation => @observation, :project => @project, :user => @observation.user)
    expect(project_observation).to be_observed_in_bounding_box_of(place)
  end
  
end

describe ProjectObservation, "observed_in_place" do
  it "should use private coordinates" do
    place = make_place_with_geom(:name => "Berkeley")
    place.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
    
    project_observation = make_project_observation
    observation = project_observation.observation
    observation.update(:latitude => 37.8732, :longitude => -122.263)
    project_observation.reload

    expect(project_observation).to be_observed_in_place(place)
    observation.update(:latitude => 37, :longitude => -122)
    project_observation.reload
    expect(project_observation).not_to be_observed_in_place(place)
    observation.update(:private_latitude => 37.8732, :private_longitude => -122.263)
    observation.save
    project_observation.reload
    expect(project_observation).to be_observed_in_place(place)
  end
end

describe ProjectObservation, "wild?" do
  let(:p) { Project.make! }
  it "should be false if observation captive_cultivated" do
    po = make_project_observation
    po.observation.update(:captive_flag => true)
    po.reload
    expect(po).not_to be_wild
  end
  it "should be true if observation not captive_cultivated" do
    po = make_project_observation
    expect(po).to be_wild
  end
end

describe ProjectObservation, "captive?" do
  let(:p) { Project.make! }
  it "should be true if observation captive_cultivated" do
    po = make_project_observation
    po.observation.update(:captive_flag => true)
    po.reload
    expect(po).to be_captive
  end
  it "should be false if observation not captive_cultivated" do
    po = make_project_observation
    expect(po).not_to be_captive
  end
end

describe ProjectObservation, "coordinates_shareable_by_project_curators?" do
  let(:p) { 
    p = Project.make!
    ProjectObservationRule.make!(ruler: p, operator: "coordinates_shareable_by_project_curators?")
    p
  }
  let(:o) { Observation.make!(user: pu.user) }
  let(:po_by_observer) { ProjectObservation.make(project: p, user: o.user, observation: o) }
  let(:po_by_no_one) { ProjectObservation.make(project: p, user: nil, observation: o) }
  let(:po_by_curator) { ProjectObservation.make(project: p, user: p.user, observation: o) }
  let(:po_by_non_curator) { 
    new_pu = ProjectUser.make!(project: p)
    po = ProjectObservation.make(project: p, user: new_pu.user, observation: o)
  }
  describe "when observer allows curator coordinate access for observations added by anyone" do
    let(:pu) { ProjectUser.make!(project: p, preferred_curator_coordinate_access: ProjectUser::CURATOR_COORDINATE_ACCESS_ANY) }
    it "should be true when submitted by the observer" do
      expect( po_by_observer ).to be_valid
      expect( po_by_observer ).to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by no one" do
      expect( po_by_no_one ).to be_valid
      expect( po_by_no_one ).to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by a project curator" do
      expect( po_by_curator ).to be_valid
      expect( po_by_curator ).to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by a non-curator" do
      expect( po_by_non_curator ).to be_valid
      expect( po_by_non_curator ).to be_coordinates_shareable_by_project_curators
    end
  end
  describe "when observer allows curator coordinate access for observations added by the observer" do
    let(:pu) { ProjectUser.make!(project: p, preferred_curator_coordinate_access: ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER) }
    it "should be true when submitted by the observer" do
      expect( po_by_observer ).to be_valid
      expect( po_by_observer ).to be_prefers_curator_coordinate_access
      expect( po_by_observer ).to be_coordinates_shareable_by_project_curators
    end
    it "should be false when submitted by no one" do
      expect( po_by_no_one ).not_to be_valid
      expect( po_by_no_one ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be false when submitted by a project curator" do
      expect( po_by_curator ).not_to be_valid
      expect( po_by_curator ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be false when submitted by a non-curator" do
      expect( po_by_non_curator ).not_to be_valid
      expect( po_by_non_curator ).not_to be_coordinates_shareable_by_project_curators
    end
  end
  describe "when observer disallows curator coordinate access" do
    let(:pu) { ProjectUser.make!(project: p, preferred_curator_coordinate_access: ProjectUser::CURATOR_COORDINATE_ACCESS_NONE) }
    it "should be false when submitted by the observer" do
      expect( po_by_observer ).not_to be_valid
      expect( po_by_observer ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be false when submitted by no one" do
      expect( po_by_no_one ).not_to be_valid
      expect( po_by_no_one ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be false when submitted by a project curator" do
      expect( po_by_curator ).not_to be_valid
      expect( po_by_curator ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be false when submitted by a non-curator" do
      expect( po_by_non_curator ).not_to be_valid
      expect( po_by_non_curator ).not_to be_coordinates_shareable_by_project_curators
    end
  end

  describe "when project observation allows curator coordinate access" do
    let(:pu) { ProjectUser.make!(project: p) }
    it "should be true when submitted by the observer" do
      po_by_observer.update( prefers_curator_coordinate_access: true )
      expect( po_by_observer ).to be_valid
      expect( po_by_observer ).to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by no one" do
      po_by_no_one.update( prefers_curator_coordinate_access: true )
      unless po_by_no_one.valid?
        puts "po_by_no_one.errors: #{po_by_no_one.errors.full_messages.to_sentence}"
      end
      expect( po_by_no_one ).to be_valid
      expect( po_by_no_one ).to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by a project curator" do
      po_by_curator.update( prefers_curator_coordinate_access: true )
      expect( po_by_curator ).to be_valid
      expect( po_by_curator ).to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by a non-curator" do
      po_by_non_curator.update( prefers_curator_coordinate_access: true )
      expect( po_by_non_curator ).to be_valid
      expect( po_by_non_curator ).to be_coordinates_shareable_by_project_curators
    end
  end
  describe "when project observation disallows curator coordinate access for observations added by curators" do
    let(:pu) { ProjectUser.make!(project: p) }
    it "should be true when submitted by the observer" do
      po_by_observer.prefers_curator_coordinate_access = false
      expect( po_by_observer ).not_to be_valid
      expect( po_by_observer ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by no one" do
      po_by_no_one.prefers_curator_coordinate_access = false
      expect( po_by_no_one ).not_to be_valid
      expect( po_by_no_one ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by a project curator" do
      po_by_curator.prefers_curator_coordinate_access = false
      expect( po_by_curator ).not_to be_valid
      expect( po_by_curator ).not_to be_coordinates_shareable_by_project_curators
    end
    it "should be true when submitted by a non-curator" do
      po_by_non_curator.prefers_curator_coordinate_access = false
      expect( po_by_non_curator ).not_to be_valid
      expect( po_by_non_curator ).not_to be_coordinates_shareable_by_project_curators
    end
  end
end

describe ProjectObservation, "to_csv" do
  it "should include headers for project observation fields" do
    pof = ProjectObservationField.make!
    of = pof.observation_field
    p = pof.project
    po = make_project_observation(:project => p)
    expect(ProjectObservation.to_csv([po]).to_s).to be =~ /#{of.name}/
  end

  it "should include values for project observation fields" do
    pof = ProjectObservationField.make!
    of = pof.observation_field
    p = pof.project
    po = make_project_observation(:project => p)
    ofv = ObservationFieldValue.make!(:observation => po.observation, :observation_field => of, :value => "foo")
    csv = ProjectObservation.to_csv([po])
    rows = CSV.parse(csv)
    ofv_index = rows[0].index(of.name)
    expect(rows[1][ofv_index]).to eq ofv.value
  end

  it "should include values for project observation fields regardless of case" do
    of = ObservationField.make!( name: "This IS %#!$ Capitalized" )
    pof = ProjectObservationField.make!( observation_field: of )
    p = pof.project
    po = make_project_observation(:project => p)
    ofv = ObservationFieldValue.make!(:observation => po.observation, :observation_field => of, :value => "foo")
    csv = ProjectObservation.to_csv([po])
    rows = CSV.parse(csv)
    ofv_index = rows[0].index(of.name)
    expect(rows[1][ofv_index]).to eq ofv.value
  end
end

describe ProjectObservation, "elastic indexing" do
  #
  # To test the touch_observation callback correctly, we need to enable full
  # db commits (e.g. no transations) and manually create indices
  #
  before(:all) do
    Observation.__elasticsearch__.client.delete_by_query(
      index: Observation.index_name,
      body: { query: { match_all: { } } },
      conflicts: "proceed"
    )
    Identification.__elasticsearch__.client.delete_by_query(
      index: Identification.index_name,
      body: { query: { match_all: { } } },
      conflicts: "proceed"
    )
  end

  it "should update projects for observations" do
    p = Project.make!
    expect( Observation.elastic_query(projects: [p.id]) ).to be_blank
    po = ProjectObservation.make!(project: p)
    expect( Observation.elastic_query(project: [p.id]) ).not_to be_blank
  end

  it "should not remove other project IDs from the observation" do
    p = Project.make!
    o = Observation.make!
    po = ProjectObservation.make!(project: p, observation: o)
    expect( Observation.elastic_query(project: [p.id]) ).not_to be_blank
    o.reload
    p2 = Project.make!
    po2 = ProjectObservation.make!(project: p2, observation: o)
    expect( Observation.elastic_query(project: [p.id]) ).not_to be_blank
    expect( Observation.elastic_query(project: [p2.id]) ).not_to be_blank
  end
end

describe ProjectObservation, "notify_observer" do
  before { enable_has_subscribers }
  after { disable_has_subscribers }
  it "does not throw an error if its observation for some reason is missing" do
    po = ProjectObservation.make!
    Observation.where( id: po.observation_id ).delete_all
    expect {
      po.notify_observer( :observation )
    }.to_not raise_error
  end
end

describe ProjectObservation, "to_csv_column" do
  it "does not throw an error if its observation for some reason is missing" do
    po = ProjectObservation.make!
    Observation.where( id: po.observation_id ).delete_all
    expect {
      expect( po.to_csv_column( "private_place_guess" ) ).to be_nil
    }.to_not raise_error
  end
end

def setup_project_and_user
  @project_user = ProjectUser.make!
  @project = @project_user.project
  @taxon = Taxon.make!(rank: Taxon::SPECIES)
  @observation = Observation.make!(:user => @project_user.user, :taxon => @taxon)
end
