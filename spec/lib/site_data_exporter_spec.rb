# frozen_string_literal: true

require File.expand_path( "../spec_helper", __dir__ )

describe SiteDataExporter do
  elastic_models( Observation )
  describe "export" do
    describe "for a site with one obs by a site user" do
      let( :site ) { create :site }
      let( :obs ) { make_research_grade_observation( site: site, user: create( :user, site: site ) ) }

      # SiteDataExporter uses Parallel to split the work of exporting across
      # subprocesses... which will not have access to the transaction in
      # which the test data are created, so we can't use transactions as a
      # cleaner strategy here
      around( :each ) do | example |
        DatabaseCleaner.strategy = :truncation
        example.run
        DatabaseCleaner.strategy = :transaction
      end

      before do
        expect( obs.user.site ).to eq site
        @archive_path = SiteDataExporter.new( site, num_processes: 1 ).export
      end

      it "should generate a zip file" do
        expect( @archive_path ).to end_with ".zip"
        expect( File.exist?( @archive_path ) ).to be true
      end

      it "should generate a csv with data" do
        dir_path = File.dirname( @archive_path )
        system "unzip -qod #{dir_path} #{@archive_path}", exception: true
        basename = SiteDataExporter.basename_for_site( site )
        rows = CSV.open( File.join( dir_path, basename, "#{basename}-observations.csv" ) ).to_a
        expect( rows.size ).to eq 2
        expect( rows[1][SiteDataExporter::OBS_COLUMNS.index( "id" )].to_i ).to eq obs.id
      end
    end
  end
end
