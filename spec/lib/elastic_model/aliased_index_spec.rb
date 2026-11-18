# frozen_string_literal: true

require "spec_helper"

describe ElasticModel::AliasedIndex do
  let( :aliased_index ) { ElasticModel::AliasedIndex.new( Post ) }
  let( :client ) { Post.__elasticsearch__.client }
  let( :alias_name ) { Post.index_name }
  let( :physical_name ) { "#{Post.index_name}_v1" }

  # Other specs need the posts index in its standard state.
  after do
    aliased_index.delete!
    aliased_index.create!
  end

  def uuid_of( index )
    client.indices.get_settings( index: index ).body[index]["settings"]["index"]["uuid"]
  end

  describe "#create!" do
    context "when nothing exists" do
      before { aliased_index.delete! }

      it "creates the versioned index behind a write alias" do
        aliased_index.create!
        aliases = client.indices.get_alias( name: alias_name ).body
        expect( aliases.keys ).to eq [physical_name]
        expect( aliases[physical_name]["aliases"][alias_name]["is_write_index"] ).to be true
      end

      it "creates the index with the model's mappings, settings and version" do
        aliased_index.create!
        mappings = client.indices.get_mapping( index: physical_name ).body[physical_name]["mappings"]
        expect( mappings["_meta"] ).to eq( "version" => 1 )
        expect( mappings["_source"]["excludes"] ).to eq ["body"]
        expect( mappings["properties"]["body"]["store"] ).to be true
        settings = client.indices.get_settings( index: physical_name ).body[physical_name]["settings"]
        expect( settings["index"]["analysis"]["analyzer"] ).to include "ascii_snowball_analyzer"
      end
    end

    context "when the alias exists" do
      it "raises Exists and changes nothing" do
        uuid = uuid_of( physical_name )
        expect { aliased_index.create! }.to raise_error( ElasticModel::AliasedIndex::Exists, /already exists/ )
        expect( uuid_of( physical_name ) ).to eq uuid
        expect( client.indices.get_alias( name: alias_name ).body.keys ).to eq [physical_name]
      end
    end

    context "when a concrete index has the alias name" do
      before do
        aliased_index.delete!
        client.indices.create( index: alias_name )
      end

      it "raises Exists and leaves the concrete index in place" do
        expect { aliased_index.create! }.to raise_error( ElasticModel::AliasedIndex::Exists, /delete it first/i )
        expect( client.indices.exists( index: alias_name ) ).to be true
        expect( client.indices.exists_alias( name: alias_name ) ).to be false
        expect( client.indices.exists( index: physical_name ) ).to be false
      end
    end
  end

  describe "#delete!" do
    it "removes the versioned index and the alias" do
      aliased_index.delete!
      expect( client.indices.exists( index: physical_name ) ).to be false
      expect( client.indices.exists_alias( name: alias_name ) ).to be false
      expect( client.indices.exists( index: alias_name ) ).to be false
    end

    it "removes a versioned index the alias no longer points at" do
      aliased_index.delete!
      client.indices.create( index: "#{alias_name}_v2" )
      aliased_index.delete!
      expect( client.indices.exists( index: "#{alias_name}_v2" ) ).to be false
    end

    it "removes a concrete index with the alias name" do
      aliased_index.delete!
      client.indices.create( index: alias_name )
      aliased_index.delete!
      expect( client.indices.exists( index: alias_name ) ).to be false
    end

    it "does nothing when nothing exists" do
      aliased_index.delete!
      expect { aliased_index.delete! }.not_to raise_error
    end
  end

  describe "#exists?" do
    it "is true for the alias and false once deleted" do
      expect( aliased_index.exists? ).to be true
      aliased_index.delete!
      expect( aliased_index.exists? ).to be false
    end

    it "is false for a concrete index with the alias name" do
      aliased_index.delete!
      client.indices.create( index: alias_name )
      expect( aliased_index.exists? ).to be false
    end
  end

  describe "indexing through the alias" do
    before { enable_elastic_indexing( Post, use_transactional_fixtures: false ) }

    it "writes posts and trips to the versioned index" do
      author = User.make!
      post = Post.make!( user: author, parent: author )
      trip = Trip.make!( user: author, parent: author )
      Post.elastic_index!( ids: [post.id, trip.id] )
      expect( client.get( index: physical_name, id: post.id ).body["found"] ).to be true
      expect( client.get( index: physical_name, id: trip.id ).body["found"] ).to be true
    end
  end

  describe "Post subclasses" do
    it "share the version, alias and physical index" do
      expect( Trip.es_index_version ).to eq 1
      expect( Trip.index_name ).to eq Post.index_name
      expect( ElasticModel::AliasedIndex.new( Trip ).physical_name ).to eq physical_name
    end
  end
end
