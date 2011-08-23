require File.dirname(__FILE__) + '/../spec_helper.rb'

describe QualityMetric, "creation" do
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    o.quality_grade.should == Observation::RESEARCH_GRADE
    qc = QualityMetric.make(:observation => o, :metric => QualityMetric::METRICS.first, :agree => false)
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
  end
end

describe QualityMetric, "destruction" do
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    o.quality_grade.should == Observation::RESEARCH_GRADE
    qc = QualityMetric.make(:observation => o, :metric => QualityMetric::METRICS.first, :agree => false)
    o.reload
    o.quality_grade.should == Observation::CASUAL_GRADE
    qc.destroy
    o.reload
    o.quality_grade.should == Observation::RESEARCH_GRADE
  end
end
