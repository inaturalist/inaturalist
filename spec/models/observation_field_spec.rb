require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ObservationField do
  it { is_expected.to belong_to :user }
  it { is_expected.to have_many(:observation_field_values).dependent :destroy }
  it { is_expected.to have_many(:observations).through :observation_field_values }
  it { is_expected.to have_many(:project_observation_fields).dependent :destroy }
  it { is_expected.to have_many(:projects).through :project_observation_fields }
  it { is_expected.to have_many(:comments).dependent :destroy }

  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_length_of(:name).is_at_most 255 }
  it { is_expected.to validate_length_of(:description).is_at_most(255).allow_blank }

  elastic_models( Observation, Project )

  describe "validation" do
    it "should strip allowed values" do
      of = build_stubbed :observation_field, allowed_values: "foo |bar"
      of.run_callbacks :validation

      expect(of.allowed_values).to eq "foo|bar"
    end
    it "should fail if allowed_values doesn't have pipes" do
      expect { create :observation_field, allowed_values: "foo" }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not allow tags in the name" do
      of = build_stubbed :observation_field, name: "hey <script>"
      of.run_callbacks :validation

      expect(of.name).to eq"hey"
    end
    it "should not allow tags in the description" do
      of = build_stubbed :observation_field, description: "hey <script>"
      of.run_callbacks :validation

      expect(of.description).to eq "hey"
    end
    it "should not allow tags in the allowed_values" do
      of = build_stubbed :observation_field, allowed_values: "hey|now <script>"
      of.run_callbacks :validation

      expect(of.allowed_values).to eq "hey|now"
    end
  end

  describe "editing" do
    it "should reindex observations if the name is changed" do
      o = Observation.make!
      of = ObservationField.make!(name: "oldname")
      ofv = ObservationFieldValue.make!(observation: o, observation_field: of)
      expect( Observation.page_of_results({ "field:oldname": nil }).total_entries ).to eq 1
      without_delay{ of.update(name: "newname") }
      new_of_with_oldname = ObservationField.make!(name: "oldname")
      expect( Observation.page_of_results({ "field:oldname": nil }).total_entries ).to eq 0
      expect( Observation.page_of_results({ "field:newname": nil }).total_entries ).to eq 1
    end

    it "should reindex projects" do
      of = ObservationField.make!( datatype: "numeric" )
      proj = Project.make!
      pof = ProjectObservationField.make!( project: proj, observation_field: of )
      Project.elastic_index!( ids: [proj.id] )
      expect( Project.elastic_search( id: proj.id ).results.results.first.
        project_observation_fields.first.observation_field.datatype ).to eq "numeric"
      without_delay{ of.update( datatype: "text" ) }
      expect( Project.elastic_search( id: proj.id ).results.results.first.
        project_observation_fields.first.observation_field.datatype ).to eq "text"
    end
  end

  describe "destruction" do
    it "should not be possible if assosiated projects exist"
    it "should not be possible if assosiated observations exist"
  end

  describe "merge" do
    let(:keeper) { create :observation_field }
    let(:reject) { create :observation_field }

    it "should delete the reject" do
      keeper.merge(reject)
      expect(ObservationField.find_by_id(reject.id)).to be_blank
    end

    context "with allowed values" do
      let!(:keeper) { create :observation_field, allowed_values: "a|b" }
      let!(:reject) { create :observation_field, allowed_values: "c|d"  }

      it "should merge requested allowed values" do
        keeper.merge(reject, merge: [:allowed_values])

        expect(keeper.allowed_values).to eq "a|b|c|d"
      end

      it "should keep requested allowed values" do
        keeper.merge(reject, keep: [:allowed_values])

        expect(keeper.allowed_values).to eq "c|d"
      end
    end

    it "should update observation field for the observation field values of the reject" do
      ofv = create :observation_field_value, observation_field: reject
      keeper.merge(reject)
      ofv.reload
      expect(ofv.observation_field).to eq keeper
    end

    it "should create a notification for all users of the reject"

    it "should not be possible for a reject in use by a project" do
      create :project_observation_field, observation_field: reject
      keeper.merge(reject)

      expect(ObservationField.find_by_id(reject.id)).not_to be_blank
    end
  end

end
