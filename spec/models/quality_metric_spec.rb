require File.dirname(__FILE__) + '/../spec_helper.rb'

describe QualityMetric, "creation" do
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    o.quality_grade.should == Observation::RESEARCH_GRADE
    qc = QualityMetric.make!(:observation => o, :metric => QualityMetric::METRICS.first, :agree => false)
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
  end
end

describe QualityMetric, "destruction" do
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    o.quality_grade.should == Observation::RESEARCH_GRADE
    qc = QualityMetric.make!(:observation => o, :metric => QualityMetric::METRICS.first, :agree => false)
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
    qc.destroy
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
  end
end

describe QualityMetric, "wild" do
  let(:o) { Observation.make! }
  before do
    o.should_not be_captive
  end
  it "should set captive on the observation" do
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    o.reload
    o.should be_captive
  end

  it "should set captive on the observation to false if majority agree" do
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => true)
    o.reload
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => true)
    o.reload
    o.should_not be_captive
  end
  it "should set captive on the observation to true if majority disagree" do
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    o.reload
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => true)
    o.reload
    o.should be_captive
  end
end
