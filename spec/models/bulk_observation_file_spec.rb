# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe BulkObservationFile, "import_file" do
  let(:user) { User.make! }
  before do
    @work_path = File.join(Dir::tmpdir, "import_file_test-#{Time.now.to_i}.csv")
    @headers = [:name, :date, :description, :place, :latitude, :longitude, :tags, :geoprivacy]
    load_test_taxa
    CSV.open(@work_path, 'w') do |csv|
      csv << @headers
      csv << [
        @Calypte_anna.name,
        "2007-08-20",
        "Beautiful little creature",
        "Leona Canyon Regional Park, Oakland, CA, USA",
        37.7454,
        -122.111,
        "cute, snakes",
        "open"
      ]
    end
  end
  it "should create an observation with the right species_guess" do
    bof = BulkObservationFile.new(@work_path, nil, nil, user)
    bof.perform
    user.observations.last.species_guess.should eq @Calypte_anna.name
  end
  describe "with project" do
    before do
      @project_user = ProjectUser.make!
      @project = @project_user.project
    end
    it "should add to project" do
      bof = BulkObservationFile.new(@work_path, @project.id, nil, @project_user.user)
      bof.perform
      @project_user.user.observations.last.projects.should include(@project)
    end
    it "should not add an extra identification" do
      bof = BulkObservationFile.new(@work_path, @project.id, nil, @project_user.user)
      bof.perform
      @project_user.user.observations.last.identifications.count.should eq 1
    end
  end
end
