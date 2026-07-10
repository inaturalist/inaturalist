# frozen_string_literal: true

require "spec_helper"

describe DataPartnerLinkers::GBIF do
  let( :data_partner ) { DataPartner.make( name: "GBIF" ) }
  let( :options ) do
    {
      username: "testuser",
      password: "testpass",
      notification_address: "tester@example.com",
      logger: Logger.new( IO::NULL )
    }
  end
  let( :linker ) { DataPartnerLinkers::GBIF.new( data_partner, options ) }

  def gbif_href( gbif_id )
    "http://www.gbif.org/occurrence/#{gbif_id}"
  end

  def make_gbif_link( observation, gbif_id, updated_at: nil )
    link = ObservationLink.create!(
      observation: observation,
      href: gbif_href( gbif_id ),
      href_name: "GBIF",
      rel: "alternate"
    )
    link.update_columns( updated_at: updated_at ) if updated_at
    link
  end

  # Writes a minimal occurrence.txt archive and stubs the linker's network
  # methods so `run` processes the fixture rows directly
  def stub_archive( rows )
    tmp_path = Dir.mktmpdir
    lines = [%w(gbifID catalogNumber species).join( "\t" )]
    rows.each do | row |
      lines << [row[:gbif_id], row[:catalog_number], "Clarkia breweri"].join( "\t" )
    end
    File.write( File.join( tmp_path, "occurrence.txt" ), lines.join( "\n" ) )
    allow( linker ).to receive( :request )
    allow( linker ).to receive( :generating ).and_return( false )
    allow( linker ).to receive( :download )
    linker.instance_variable_set( :@tmp_path, tmp_path )
    linker.instance_variable_set( :@status, { "totalRecords" => rows.size } )
  end

  def stub_elastic_index
    allow( Observation ).to receive( :elastic_index! )
  end

  describe "request_filtered" do
    it "posts an SQL_TSV_ZIP download request selecting only the fields process_result uses" do
      allow( RestClient ).to receive( :post ).and_return( "sql-download-key" )
      linker.request_filtered
      expect( RestClient ).to have_received( :post ) do | url, payload, _headers |
        expect( url ).to eq "https://testuser:testpass@api.gbif.org/v1/occurrence/download/request"
        body = JSON.parse( payload )
        expect( body["format"] ).to eq "SQL_TSV_ZIP"
        expect( body["sql"] ).to match( /\ASELECT\s+gbifID,\s*catalogNumber\s+FROM\s+occurrence/i )
        expect( body["sql"] ).to include( DataPartnerLinkers::GBIF::DATASET_KEY )
      end
      expect( linker.instance_variable_get( :@key ) ).to eq "sql-download-key"
    end
  end

  describe "run with the sql_download option" do
    let( :options ) do
      {
        username: "testuser",
        password: "testpass",
        notification_address: "tester@example.com",
        logger: Logger.new( IO::NULL ),
        sql_download: true
      }
    end

    it "requests via request_filtered instead of request" do
      observation = Observation.make!
      stub_archive( [{ gbif_id: 888, catalog_number: observation.id }] )
      allow( linker ).to receive( :request )
      allow( linker ).to receive( :request_filtered )
      stub_elastic_index
      linker.run
      expect( linker ).to have_received( :request_filtered )
      expect( linker ).not_to have_received( :request )
    end
  end

  describe "run" do
    it "touches existing links with one update and does not reindex them" do
      observation = Observation.make!
      link = make_gbif_link( observation, 111, updated_at: 1.month.ago )
      stub_archive( [{ gbif_id: 111, catalog_number: observation.id }] )
      stub_elastic_index
      expect do
        linker.run
      end.not_to change( ObservationLink, :count )
      expect( link.reload.updated_at ).to be > 1.hour.ago
      expect( linker.instance_variable_get( :@old_count ) ).to eq 1
      expect( linker.instance_variable_get( :@new_count ) ).to eq 0
      expect( Observation ).not_to have_received( :elastic_index! )
    end

    it "creates links for existing observations and queues them for delayed indexing" do
      observation = Observation.make!
      stub_archive( [{ gbif_id: 222, catalog_number: observation.id }] )
      stub_elastic_index
      expect do
        linker.run
      end.to change( ObservationLink, :count ).by( 1 )
      link = ObservationLink.last
      expect( link.observation_id ).to eq observation.id
      expect( link.href ).to eq gbif_href( 222 )
      expect( link.href_name ).to eq "GBIF"
      expect( link.rel ).to eq "alternate"
      expect( linker.instance_variable_get( :@new_count ) ).to eq 1
      expect( Observation ).to have_received( :elastic_index! ).with(
        hash_including( delay: true, ids: [observation.id] )
      )
    end

    it "skips rows whose observation does not exist" do
      stub_archive( [{ gbif_id: 333, catalog_number: Observation.maximum( :id ).to_i + 1000 }] )
      stub_elastic_index
      expect do
        linker.run
      end.not_to change( ObservationLink, :count )
      expect( linker.instance_variable_get( :@missing_count ) ).to eq 1
      expect( Observation ).not_to have_received( :elastic_index! )
    end

    it "deletes stale GBIF links and queues their observations for reindexing" do
      observation = Observation.make!
      stale_link = make_gbif_link( observation, 444, updated_at: 1.month.ago )
      other_partner_link = ObservationLink.create!(
        observation: observation,
        href: "http://biocache.ala.org.au/occurrences/abc-123",
        href_name: "Atlas of Living Australia",
        rel: "alternate"
      )
      other_partner_link.update_columns( updated_at: 1.month.ago )
      stub_archive( [] )
      stub_elastic_index
      expect do
        linker.run
      end.to change( ObservationLink, :count ).by( -1 )
      expect( ObservationLink.where( id: stale_link.id ) ).not_to exist
      expect( ObservationLink.where( id: other_partner_link.id ) ).to exist
      expect( Observation ).to have_received( :elastic_index! ).with(
        hash_including( delay: true, ids: [observation.id] )
      )
    end

    describe "in debug mode" do
      let( :options ) do
        {
          username: "testuser",
          password: "testpass",
          notification_address: "tester@example.com",
          logger: Logger.new( IO::NULL ),
          debug: true
        }
      end

      it "performs no writes" do
        touched_observation = Observation.make!
        new_observation = Observation.make!
        stale_observation = Observation.make!
        touched_link = make_gbif_link( touched_observation, 555, updated_at: 1.month.ago )
        stale_link = make_gbif_link( stale_observation, 666, updated_at: 1.month.ago )
        stub_archive( [
                       { gbif_id: 555, catalog_number: touched_observation.id },
                       { gbif_id: 777, catalog_number: new_observation.id }
                     ] )
        stub_elastic_index
        expect do
          linker.run
        end.not_to change( ObservationLink, :count )
        expect( touched_link.reload.updated_at ).to be < 1.day.ago
        expect( ObservationLink.where( id: stale_link.id ) ).to exist
        expect( linker.instance_variable_get( :@old_count ) ).to eq 1
        expect( linker.instance_variable_get( :@new_count ) ).to eq 1
        expect( Observation ).not_to have_received( :elastic_index! )
      end
    end
  end
end
