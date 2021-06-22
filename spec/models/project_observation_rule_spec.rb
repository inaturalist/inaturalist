require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservationRule do
  describe "validation" do
    it "should add errors to project observation when validation fails" do
      por = ProjectObservationRule.make!(:operator => "identified?")
      po = ProjectObservation.make(:project => por.ruler)
      expect(po).not_to be_valid
    end
  end

  describe "creation" do
    it "should not allow more than one operator without an operand per project" do
      por1 = ProjectObservationRule.make!(:operator => "identified?")
      por2 = ProjectObservationRule.make(:operator => "identified?", :ruler => por1.ruler)
      expect(por2).not_to be_valid
      expect(por2.errors[:operator]).not_to be_blank
    end
    it "should not allow more than one operator/operand pair per project" do
      por1 = ProjectObservationRule.make!(:operator => "in_taxon?", :operand => Taxon.make!)
      por2 = ProjectObservationRule.make(:operator => "in_taxon?", :operand => por1.operand, :ruler => por1.ruler)
      expect(por2).not_to be_valid
    end
    it "should allow more than one operator with different operands per project" do
      por1 = ProjectObservationRule.make!(:operator => "in_taxon?", :operand => Taxon.make!)
      por2 = ProjectObservationRule.make(:operator => "in_taxon?", :operand => Taxon.make!, :ruler => por1.ruler)
      expect(por2).to be_valid
    end
    it "should test rules with the same operator using OR" do
      p = Project.make!
      por1 = ProjectObservationRule.make!(:operator => "in_taxon?", :operand => Taxon.make!, :ruler => p)
      por2 = ProjectObservationRule.make!(:operator => "in_taxon?", :operand => Taxon.make!, :ruler => p)
      p.reload
      pu = ProjectUser.make!(:project => p)
      o1 = Observation.make!(:user => pu.user, :taxon => por1.operand)
      o2 = Observation.make!(:user => pu.user, :taxon => por2.operand)
      o3 = Observation.make!(:user => pu.user, :taxon => Taxon.make!)
      expect(ProjectObservation.make(:project => p, :observation => o1)).to be_valid
      expect(ProjectObservation.make(:project => p, :observation => o2)).to be_valid
      expect(ProjectObservation.make(:project => p, :observation => o3)).not_to be_valid
    end
    it "should test rules with different operators using AND" do
      p = Project.make!
      por1 = ProjectObservationRule.make!(:operator => "in_taxon?", :operand => Taxon.make!, :ruler => p)
      por2 = ProjectObservationRule.make!(:operator => "georeferenced?", :ruler => p)
      p.reload
      pu = ProjectUser.make!(:project => p)
      o1 = Observation.make!(:user => pu.user, :taxon => por1.operand)
      o2 = Observation.make!(:user => pu.user, :taxon => Taxon.make!)
      o3 = Observation.make!(:user => pu.user, :latitude => 1, :longitude => 1, :taxon => Taxon.make!)
      o4 = Observation.make!(:user => pu.user, :latitude => 1, :longitude => 1, :taxon => por1.operand)
      expect(ProjectObservation.make(:project => p, :observation => o1)).not_to be_valid # missing coords
      expect(ProjectObservation.make(:project => p, :observation => o2)).not_to be_valid # missing coords and wrong taxon
      expect(ProjectObservation.make(:project => p, :observation => o3)).not_to be_valid # wrong taxon
      expect(ProjectObservation.make(:project => p, :observation => o4)).to be_valid
    end
    it "validates observed_in_place?" do
      place = make_place_with_geom
      p = Project.make!
      o = Observation.make!
      # create the rule
      p.project_observation_rules.create(operand: place, operator: "observed_in_place?")
      # invalid because obs is not in the place
      expect(ProjectObservation.make(project: p, observation: o)).not_to be_valid
      o.update_attributes(latitude: place.latitude, longitude: place.longitude)
      # valid when obs is in the place
      expect(ProjectObservation.make(project: p, observation: o)).to be_valid
      ProjectObservation.destroy_all
      Place.destroy_all
      # invalid (not not an error) when the rule references a missing place
      expect(ProjectObservation.make(project: p, observation: o)).not_to be_valid
    end
  end

  it "resets project last_aggregated_at on creation and deletion" do
    p = Project.make!(last_aggregated_at: Time.now)
    rule = p.project_observation_rules.create(operator: "in_taxon?", operand: Taxon.make!)
    p.reload
    expect( p.last_aggregated_at ).to be_nil
    p.update_columns(last_aggregated_at: Time.now)
    expect( p.last_aggregated_at ).to_not be_nil
    rule.destroy
    p.reload
    expect( p.last_aggregated_at ).to be_nil
  end

  describe "project observation_requirements_updated_at" do
    it "should reset on creation" do
      proj = Project.make!( project_type: "collection", prefers_user_trust: true )
      expect( proj.observation_requirements_updated_at ).to be < proj.created_at
      pu = ProjectUser.make!(
        project: proj,
        prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
      )
      rule = proj.project_observation_rules.create( operator: "in_taxon?", operand: Taxon.make! )
      proj.reload
      expect( proj.observation_requirements_updated_at ).to be > proj.created_at
    end

    it "should reset on deletion" do
      proj = Project.make!( project_type: "collection", prefers_user_trust: true )
      rule = proj.project_observation_rules.create( operator: "in_taxon?", operand: Taxon.make! )
      expect( proj.observation_requirements_updated_at ).to be < proj.created_at
      pu = ProjectUser.make!(
        project: proj,
        prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
      )
      rule.destroy
      proj.reload
      expect( proj.observation_requirements_updated_at ).to be > proj.created_at
    end
  end

end
