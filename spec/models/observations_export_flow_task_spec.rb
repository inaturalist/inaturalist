require File.expand_path("../../spec_helper", __FILE__)

describe ObservationsExportFlowTask, "run" do
  before(:all) do
    @o = Observation.make!
    @ft = ObservationsExportFlowTask.make
    @ft.inputs.build(:extra => {:query => "user_id=#{@o.user_id}"})
    @ft.save!
    @ft.run
  end
  it "should generate a zipped csv archive by default" do
    output = @ft.outputs.first
    output.should_not be_blank
    output.file.path.should =~ /csv.zip$/
  end

  it "should filter by user_id" do
    csv = CSV.open(File.join(@ft.work_path, "#{@ft.basename}.csv")).to_a
    csv.size.should eq 2
    csv[1].should include @o.id.to_s
  end

  it "should allow JSON output" do
    ft = ObservationsExportFlowTask.make
    ft.options = {:format => "json"}
    ft.inputs.build(:extra => {:query => "user_id=#{@o.user_id}"})
    ft.save!
    ft.run
    output = ft.outputs.first
    output.should_not be_blank
    output.file.path.should =~ /json.zip$/
    lambda {
      JSON.parse(open(File.join(ft.work_path, "#{ft.basename}.json")).read)
    }.should_not raise_error
  end
end

describe ObservationsExportFlowTask, "geoprivacy" do
  it "should not include private coordinates you can't see" do
    o = make_private_observation(:taxon => Taxon.make!)
    viewer = User.make!
    ft = ObservationsExportFlowTask.make(:user => viewer)
    ft.inputs.build(:extra => {:query => "taxon_id=#{o.taxon_id}"})
    ft.save!
    ft.run 
    csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
    csv.size.should eq 2
    csv[1].should_not include o.private_latitude.to_s
  end

  it "should include private coordinates if viewing your own observations" do
    o = make_private_observation(:taxon => Taxon.make!)
    viewer = o.user
    ft = ObservationsExportFlowTask.make(:user => viewer)
    ft.inputs.build(:extra => {:query => "user_id=#{o.user_id}"})
    ft.save!
    ft.run 
    csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
    csv.size.should eq 2
    csv[1].should include o.private_latitude.to_s
  end

  it "should include private coordinates if viewing a project you curate" do
    o = make_private_observation(:taxon => Taxon.make!)
    po = make_project_observation(:observation => o, :user => o.user)
    p = po.project
    pu = without_delay do
      ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR)
    end
    viewer = pu.user
    ft = ObservationsExportFlowTask.make(:user => viewer)
    ft.inputs.build(:extra => {:query => "projects[]=#{p.id}"})
    ft.save!
    ft.run 
    csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
    csv.size.should eq 2
    csv[1].should include o.private_latitude.to_s
  end
end

describe ObservationsExportFlowTask, "columns" do
  it "should be configurable" do
    o = Observation.make!(:taxon => Taxon.make!)
    ft = ObservationsExportFlowTask.make(:options => {:columns => Observation::CSV_COLUMNS[0..0]})
    ft.inputs.build(:extra => {:query => "taxon_id=#{o.taxon_id}"})
    ft.save!
    ft.run 
    csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
    csv[0].size.should eq 1
  end

  it "should never include anything but allowed columns" do
    ft = ObservationsExportFlowTask.make(:options => {:columns => %w(delete destroy badness)})
    ft.inputs.build(:extra => {:query => "user_id=1"})
    ft.save!
    ft.export_columns.should be_blank
  end
end
