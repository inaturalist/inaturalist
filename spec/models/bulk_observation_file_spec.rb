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
    expect(user.observations.last.species_guess).to eq @Calypte_anna.name
  end

  it "should create an observation with a geom" do
    bof = BulkObservationFile.new(@work_path, nil, nil, user)
    bof.perform
    expect(user.observations.last.geom).not_to be_blank
  end

  it "should still validate coordinates" do
    work_path = File.join(Dir::tmpdir, "import_file_test-#{Time.now.to_i}.csv")
    CSV.open(@work_path, 'w') do |csv|
      csv << @headers
      csv << [
        @Calypte_anna.name,
        "2007-08-20",
        "Beautiful little creature",
        "Leona Canyon Regional Park, Oakland, CA, USA",
        200.7454,
        -122.111,
        "cute, snakes",
        "open"
      ]
    end
    bof = BulkObservationFile.new(@work_path, nil, nil, user)
    user.observations.destroy_all
    bof.perform
    expect(user.observations).to be_blank
  end

  it "should allow blank rows" do
    work_path = File.join(Dir::tmpdir, "import_file_test-#{Time.now.to_i}.csv")
    CSV.open(@work_path, 'w') do |csv|
      csv << @headers
      csv << [
        @Calypte_anna.name,
        "2007-08-20",
        "Beautiful little creature",
        "Leona Canyon Regional Park, Oakland, CA, USA",
        1,
        2,
        "cute, snakes",
        "open"
      ]
      csv << ['','','','','','','']
      csv << ['','','','','','','']
      csv << ['','','','','','','']
    end
    bof = BulkObservationFile.new(@work_path, nil, nil, user)
    user.observations.destroy_all
    bof.perform
    user.reload
    expect( user.observations.count ).to eq 1
  end
  
  describe "with project" do
    before do
      @project_user = ProjectUser.make!
      @project = @project_user.project
    end
    it "should add to project" do
      bof = BulkObservationFile.new(@work_path, @project.id, nil, @project_user.user)
      bof.perform
      expect(@project_user.user.observations.last.projects).to include(@project)
    end
    it "should not add an extra identification" do
      bof = BulkObservationFile.new(@work_path, @project.id, nil, @project_user.user)
      bof.perform
      expect(@project_user.user.observations.last.identifications.count).to eq 1
    end
  end

  describe "with coordinate system" do
    before do
      stub_config :coordinate_systems => {
        :nztm2000 => {
          :label => "NZTM2000 (NZ Transverse Mercator), EPSG:2193",
          :proj4 => "+proj=tmerc +lat_0=0 +lon_0=173 +k=0.9996 +x_0=1600000 +y_0=10000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
        },
        :nzmg => {
          :label => "NZMG (New Zealand Map Grid), EPSG:27200",
          :proj4 => "+proj=nzmg +lat_0=-41 +lon_0=173 +x_0=2510000 +y_0=6023150 +ellps=intl +datum=nzgd49 +units=m +no_defs"
        }
      }
      expect(CONFIG.coordinate_systems).not_to be_blank
      @work_path = File.join(Dir::tmpdir, "import_file_test-#{Time.now.to_i}.csv")
      @headers = [:name, :date, :description, :place, :latitude, :longitude, :tags, :geoprivacy]
      CSV.open(@work_path, 'w') do |csv|
        csv << @headers
        csv << [
          @Calypte_anna.name,
          "2000-12-23",
          "Pair seen in swamp off Kuripapango Rd.",
          "Hastings, Hawke's Bay, NZ",
          5635569, # these coordinates should be NZMG for Lat -39.380943828, Lon 176.3574072522
          1889191,
          "some,tags",
          "open"
        ]
      end
    end

    it "should create an observation with a geom" do
      bof = BulkObservationFile.new(@work_path, nil, "nzmg", user)
      bof.perform
      expect(user.observations.last.geom).not_to be_blank
    end

    it "should validate coordinates" do
      work_path = File.join(Dir::tmpdir, "import_file_test-#{Time.now.to_i}.csv")
      CSV.open(work_path, 'w') do |csv|
        csv << @headers
        csv << [
          @Calypte_anna.name,
          "2000-12-23",
          "Pair seen in swamp off Kuripapango Rd.",
          "Hastings, Hawke's Bay, NZ",
          1889206,
          5599343, # these are reversed NZMG coordinates which should fail
          "some,tags",
          "open"
        ]
      end
      bof = BulkObservationFile.new(work_path, nil, "nzmg", user)
      user.observations.destroy_all
      bof.perform
      expect(user.observations).to be_blank
    end
  end
end
