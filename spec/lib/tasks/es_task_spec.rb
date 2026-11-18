# frozen_string_literal: true

require "spec_helper"
require "rake"

describe "es rake tasks" do
  before( :all ) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require( "tasks/es", ["#{Rails.root}/lib"] )
    Rake::Task.define_task( :environment )
  end

  let( :aliased_index ) { ElasticModel::AliasedIndex.new( Post ) }
  let( :client ) { Post.__elasticsearch__.client }
  let( :physical_name ) { "#{Post.index_name}_v1" }

  # Other specs need the posts index in its standard state.
  after do
    aliased_index.delete!
    aliased_index.create!
  end

  def run_task( name, *args )
    task = Rake::Task[name]
    task.reenable
    task.invoke( *args )
  end

  describe "es:create_index" do
    it "creates the aliased index when it is missing" do
      aliased_index.delete!
      expect { run_task( "es:create_index", "Post" ) }.to output( /#{physical_name}/ ).to_stdout
      expect( client.indices.get_alias( name: Post.index_name ).body.keys ).to eq [physical_name]
    end

    it "exits non-zero when the aliased index exists" do
      expect do
        run_task( "es:create_index", "Post" )
      end.to raise_error( SystemExit ) {| e | expect( e.status ).to eq 1 }.and output( /already exists/ ).to_stdout
    end

    it "exits non-zero when a concrete index has the alias name" do
      aliased_index.delete!
      client.indices.create( index: Post.index_name )
      expect do
        run_task( "es:create_index", "Post" )
      end.to raise_error( SystemExit ) {| e | expect( e.status ).to eq 1 }.and output( /delete it first/i ).to_stdout
      expect( client.indices.exists( index: Post.index_name ) ).to be true
    end

    it "exits non-zero for a concrete model whose index exists" do
      expect do
        run_task( "es:create_index", "User" )
      end.to raise_error( SystemExit ) {| e | expect( e.status ).to eq 1 }.and output( /already exists/ ).to_stdout
    end
  end

  describe "es:recreate_index" do
    it "leaves the versioned index behind the alias when run twice" do
      expect do
        run_task( "es:recreate_index", "Post" )
        run_task( "es:recreate_index", "Post" )
      end.to output.to_stdout
      expect( client.indices.get_alias( name: Post.index_name ).body.keys ).to eq [physical_name]
    end

    it "replaces a concrete index with the aliased index" do
      aliased_index.delete!
      client.indices.create( index: Post.index_name )
      expect { run_task( "es:recreate_index", "Post" ) }.to output.to_stdout
      expect( client.indices.get_alias( name: Post.index_name ).body.keys ).to eq [physical_name]
    end
  end
end
