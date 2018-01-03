require File.expand_path("../../spec_helper", __FILE__)

describe GuidePdfFlowTask, "run" do
  it "should generate output" do
    gt = GuideTaxon.make!
    g = gt.guide
    gpft = GuidePdfFlowTask.new
    gpft.inputs.build( resource: g )
    gpft.save!
    gpft.run
    expect( gpft.outputs ).not_to be_blank
  end
end
