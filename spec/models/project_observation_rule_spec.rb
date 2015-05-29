require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservationRule, "validation" do
  it "should add errors to project observation when validation fails" do
    por = ProjectObservationRule.make!(:operator => "identified?")
    po = ProjectObservation.make(:project => por.ruler)
    expect(po).not_to be_valid
  end
end

describe ProjectObservationRule, "creation" do
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
end
