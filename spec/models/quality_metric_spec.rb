require File.dirname(__FILE__) + '/../spec_helper.rb'

describe QualityMetric, "creation" do
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
    qc = QualityMetric.make!(:observation => o, :metric => QualityMetric::METRICS.first, :agree => false)
    o.reload
    expect(o.quality_grade).to eq Observation::UNVERIFIABLE
  end
end

describe QualityMetric, "destruction" do
  it "should update observation quality_grade" do
    o = make_research_grade_observation
    expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
    qc = QualityMetric.make!(:observation => o, :metric => QualityMetric::METRICS.first, :agree => false)
    o.reload
    expect(o.quality_grade).to eq Observation::UNVERIFIABLE
    qc.destroy
    o.reload
    expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
  end
end

describe QualityMetric, "wild" do
  let(:o) { Observation.make! }
  before do
    expect(o).not_to be_captive
  end
  it "should set captive on the observation" do
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    o.reload
    expect(o).to be_captive
  end

  it "should set captive on the observation to false if majority agree" do
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => true)
    o.reload
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => true)
    o.reload
    expect(o).not_to be_captive
  end
  it "should set captive on the observation to true if majority disagree" do
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    o.reload
    QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => true)
    o.reload
    expect(o).to be_captive
  end
  it "should set captive on the observation false if metric destroyed" do
    qm = QualityMetric.make!(:observation => o, :metric => QualityMetric::WILD, :agree => false)
    o.reload
    expect(o).to be_captive
    qm.destroy
    o.reload
    expect(o).not_to be_captive
  end
end
