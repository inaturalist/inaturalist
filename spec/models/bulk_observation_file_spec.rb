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
  elastic_models( Observation )

  it "should create an observation with the right species_guess" do
    bof = BulkObservationFile.new(@work_path, user.id)
    bof.perform
    expect(user.observations.last.species_guess).to eq @Calypte_anna.name
  end

  it "should create an observation with a geom" do
    bof = BulkObservationFile.new(@work_path, user.id)
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
    bof = BulkObservationFile.new(@work_path, user.id)
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
    bof = BulkObservationFile.new(@work_path, user.id)
    user.observations.destroy_all
    bof.perform
    user.reload
    expect( user.observations.count ).to eq 1
  end

  it "should skip rows with leading pound sign" do
    t = Taxon.make!
    File.open(@work_path, 'w') do |f|
      f << <<-CSV
species guess,Date,Description,Location,Latitude / y coord / northing,Longitude / x coord / easting,Tags,Geoprivacy
#{t.name},2013-01-01 09:10:11,,1,1,,"List,Of,Tags",Private
# Buteo jamaicensis,2013-01-01 09:10:11,,1,1,,"List,Of,Tags",Private
      CSV
    end
    bof = BulkObservationFile.new(@work_path, user.id)
    user.observations.destroy_all
    bof.perform
    user.reload
    expect( user.observations.count ).to eq 1
  end

  it "should validate quotes in coordinates" do
    File.open(@work_path, 'w') do |f|
      t = Taxon.make!
      f << <<-CSV
species guess,Date,Description,Location,Latitude / y coord / northing,Longitude / x coord / easting,Tags,Geoprivacy
#{t.name},2013-01-01 09:10:11,,1",1,,"List,Of,Tags",Private
      CSV
    end
    bof = BulkObservationFile.new(@work_path, user.id)
    user.observations.destroy_all
    bof.perform
    expect(user.observations).to be_blank
  end
  
  describe "with project" do
    before do
      @project_user = ProjectUser.make!
      @project = @project_user.project
    end
    it "should add to project" do
      bof = BulkObservationFile.new(@work_path, @project_user.user_id, project_id: @project.id)
      bof.perform
      expect(@project_user.user.observations.last.projects).to include(@project)
    end
    it "should not add an extra identification" do
      bof = BulkObservationFile.new(@work_path, @project_user.user_id, project_id: @project.id)
      bof.perform
      expect(@project_user.user.observations.last.identifications.count).to eq 1
    end
    it "should add project observation fields" do
      of1 = ObservationField.make!
      of2 = ObservationField.make!
      @project.project_observation_fields.create!( observation_field: of1 )
      @project.project_observation_fields.create!( observation_field: of2 )
      of1_value = "barf"
      of2_value = "12345"
      work_path = File.join(Dir::tmpdir, "import_file_test-#{Time.now.to_i}.csv")
      CSV.open(@work_path, 'w') do |csv|
        csv << @headers + [of1.name, of2.name]
        csv << [
          @Calypte_anna.name,
          "2007-08-20",
          "Beautiful little creature",
          "Leona Canyon Regional Park, Oakland, CA, USA",
          37.7454,
          -122.111,
          "cute, snakes",
          "open",
          of1_value,
          of2_value,
          ''
        ]
      end
      bof = BulkObservationFile.new(@work_path, user.id, project_id: @project.id)
      user.observations.destroy_all
      bof.perform
      user.reload
      expect( user.observations.count ).to eq 1
      expect( user.observations.last.observation_field_values ).not_to be_blank
      expect( user.observations.last.observation_field_values.first.value ).to eq of1_value
      expect( user.observations.last.observation_field_values.last.value ).to eq of2_value
    end
  end

  describe "with coordinate system" do
    let(:proj4_nzmg) {
      "+proj=nzmg +lat_0=-41 +lon_0=173 +x_0=2510000 +y_0=6023150 +ellps=intl +datum=nzgd49 +units=m +no_defs"
    }
    before do
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
      bof = BulkObservationFile.new(@work_path, user.id, coord_system: proj4_nzmg)
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
      bof = BulkObservationFile.new(work_path, user.id, coord_system: proj4_nzmg)
      user.observations.destroy_all
      bof.perform
      expect(user.observations).to be_blank
    end
  end
end
