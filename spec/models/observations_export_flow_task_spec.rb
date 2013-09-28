require File.expand_path("../../spec_helper", __FILE__)

describe ObservationsExportFlowTask, "run" do
  before(:all) do
    @o = Observation.make!
    @ft = ObservationsExportFlowTask.new
    @ft.inputs.build(:extra => {:query => "user_id=#{@o.user_id}"})
    @ft.save!
    @ft.run
  end
  it "should generate a zipped csv archive" do
    output = @ft.outputs.first
    output.should_not be_blank
    output.file.path.should =~ /csv.zip$/
  end

  it "should filter by user_id" do
    csv = CSV.open(File.join(@ft.work_path, "#{@ft.basename}.csv")).to_a
    csv.size.should eq 2
    csv[1].should include @o.id.to_s
  end
end