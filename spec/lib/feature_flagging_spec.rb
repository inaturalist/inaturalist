# frozen_string_literal: true

require "spec_helper"

describe FeatureFlagging do
  let( :flag ) { :client_smoke_test }
  let( :experiment ) { :hello_world }
  let( :actor ) { User.make! }

  before { add_test_flags }

  def fake_actors( count )
    klass = Struct.new( :flipper_id )
    ( 1..count ).map {| i | klass.new( "User;#{i}" ) }
  end

  describe "classification by key prefix" do
    it "treats a client_ key as client-visible" do
      expect( FeatureFlagging.kind_of( "client_thing" ) ).to eq :client
      expect( FeatureFlagging.kind_of( :client_thing ) ).to eq :client
    end

    it "treats an exp_ key as an experiment" do
      expect( FeatureFlagging.kind_of( "exp_thing" ) ).to eq :experiment
    end

    it "treats any other key as server-only, without normalizing case" do
      expect( FeatureFlagging.kind_of( "thing" ) ).to eq :server
      expect( FeatureFlagging.kind_of( "Client_thing" ) ).to eq :server
    end

    it "treats a bare prefix as server-only" do
      expect( FeatureFlagging.kind_of( "client_" ) ).to eq :server
      expect( FeatureFlagging.kind_of( "exp_" ) ).to eq :server
    end

    it "derives the experiment name from its flag and back" do
      expect( FeatureFlagging.experiment_name( "exp_hello_world" ) ).to eq :hello_world
      expect( FeatureFlagging.experiment_flag( :hello_world ) ).to eq :exp_hello_world
    end

    it "describes each kind for the admin UI" do
      descriptions = %w(client_a exp_b c).map {| key | FeatureFlagging.description_for( key ) }
      expect( descriptions.uniq.size ).to eq 3
      expect( descriptions[1] ).to include "experiments.b"
    end

    it "lists every existing flag sorted by key" do
      Flipper.add( :aaa )
      expect( FeatureFlagging.feature_keys ).to eq %w(aaa client_smoke_test exp_hello_world server_smoke_test)
    end
  end

  describe "enabled?" do
    it "is false when nothing has been enabled" do
      expect( FeatureFlagging.enabled?( flag, actor ) ).to be false
    end

    it "accepts a string key" do
      Flipper.enable( flag )
      expect( FeatureFlagging.enabled?( flag.to_s, actor ) ).to be true
    end

    it "reads a server-only flag" do
      Flipper.enable( :server_smoke_test )
      expect( FeatureFlagging.enabled?( :server_smoke_test, actor ) ).to be true
    end

    it "is false for a flag that does not exist" do
      allow( Rails.logger ).to receive( :warn )
      expect( FeatureFlagging.enabled?( :not_a_real_flag ) ).to be false
    end

    it "warns once per process for a flag that does not exist" do
      allow( Rails.logger ).to receive( :warn )
      expect( Rails.logger ).to receive( :warn ).with( /not_a_real_flag/ ).once
      2.times { FeatureFlagging.enabled?( :not_a_real_flag ) }
    end

    it "warns again after the warnings are reset" do
      allow( Rails.logger ).to receive( :warn )
      expect( Rails.logger ).to receive( :warn ).with( /not_a_real_flag/ ).twice
      FeatureFlagging.enabled?( :not_a_real_flag )
      FeatureFlagging.reset_unknown_key_warnings
      FeatureFlagging.enabled?( :not_a_real_flag )
    end

    it "sees a flag created at runtime" do
      allow( Rails.logger ).to receive( :warn )
      expect( FeatureFlagging.enabled?( :client_new ) ).to be false
      Flipper.enable( :client_new )
      expect( FeatureFlagging.enabled?( :client_new ) ).to be true
    end

    it "raises for an actor that cannot be bucketed" do
      expect { FeatureFlagging.enabled?( flag, Object.new ) }.to raise_error ArgumentError
    end

    it "fails closed when the adapter raises" do
      allow( Flipper ).to receive( :enabled? ).and_raise( ActiveRecord::StatementInvalid, "boom" )
      expect( FeatureFlagging.enabled?( flag, actor ) ).to be false
    end

    it "logs when it fails closed" do
      allow( Flipper ).to receive( :enabled? ).and_raise( ActiveRecord::StatementInvalid, "boom" )
      expect( Rails.logger ).to receive( :error ).with( /#{flag}/ )
      FeatureFlagging.enabled?( flag, actor )
    end
  end

  describe "actor resolution" do
    it "buckets a user by a stable flipper_id" do
      expect( actor.flipper_id ).to eq "User;#{actor.id}"
    end

    it "treats a boolean gate as on for anonymous callers" do
      Flipper.enable( flag )
      expect( FeatureFlagging.enabled?( flag ) ).to be true
    end

    it "does not apply an actor gate to anonymous callers" do
      Flipper.enable_actor( flag, actor )
      expect( FeatureFlagging.enabled?( flag ) ).to be false
      expect( FeatureFlagging.enabled?( flag, actor ) ).to be true
    end

    it "does not apply a percentage gate to anonymous callers" do
      Flipper.enable_percentage_of_actors( flag, 100 )
      expect( FeatureFlagging.enabled?( flag ) ).to be false
    end

    it "applies the admins group" do
      Flipper.enable_group( flag, :admins )
      expect( FeatureFlagging.enabled?( flag, User.make! ) ).to be false
      expect( FeatureFlagging.enabled?( flag, make_admin ) ).to be true
    end

    # Logged-out mobile shares User(id: -1); guards prevent percentage gate misfires.
    describe "the shared anonymous user" do
      let( :anonymous_user ) do
        User.new( id: Devise::Strategies::ApplicationJsonWebToken::ANONYMOUS_USER_ID,
          login: "anonymous" )
      end

      it "is recognized as anonymous" do
        expect( anonymous_user.anonymous? ).to be true
        expect( anonymous_user.flipper_id ).to eq "User;-1"
      end

      it "resolves like no actor at all" do
        Flipper.enable( flag )
        expect( FeatureFlagging.enabled?( flag, anonymous_user ) ).to be true
        Flipper.disable( flag )
        expect( FeatureFlagging.enabled?( flag, anonymous_user ) ).to be false
      end

      it "does not pick up an actor gate on its own flipper_id" do
        Flipper.enable_actor( flag, anonymous_user )
        expect( FeatureFlagging.enabled?( flag, anonymous_user ) ).to be false
      end

      it "does not pick up a percentage gate" do
        Flipper.enable_percentage_of_actors( flag, 100 )
        expect( FeatureFlagging.enabled?( flag, anonymous_user ) ).to be false
      end

      it "is never assigned an experiment variant" do
        Flipper.enable( FeatureFlagging.experiment_flag( experiment ) )
        expect( FeatureFlagging.variant( experiment, anonymous_user ) ).to be_nil
      end
    end
  end

  describe "flags_for" do
    it "returns a boolean for every client flag, sorted by key" do
      Flipper.add( :client_zzz )
      Flipper.add( :client_aaa )
      map = FeatureFlagging.flags_for( actor )
      expect( map.keys ).to eq %i[client_aaa client_smoke_test client_zzz]
      expect( map.values ).to all( be false )
    end

    it "excludes server-only and experiment flags" do
      expect( FeatureFlagging.flags_for( actor ).keys ).to eq [flag]
    end

    it "reflects an enabled flag" do
      Flipper.enable_actor( flag, actor )
      expect( FeatureFlagging.flags_for( actor )[flag] ).to be true
      expect( FeatureFlagging.flags_for( nil )[flag] ).to be false
    end

    it "sees a flag created at runtime" do
      expect( FeatureFlagging.flags_for( actor ) ).not_to have_key :client_new
      Flipper.add( :client_new )
      expect( FeatureFlagging.flags_for( actor ) ).to have_key :client_new
    end

    it "is empty when no client flags exist" do
      Flipper.remove( flag )
      expect( FeatureFlagging.flags_for( actor ) ).to eq( {} )
    end

    it "serializes to a JSON object of booleans" do
      parsed = JSON.parse( FeatureFlagging.flags_for( actor ).to_json )
      expect( parsed ).to eq( "client_smoke_test" => false )
    end
  end

  describe "variant" do
    before { Flipper.enable( FeatureFlagging.experiment_flag( experiment ) ) }

    it "returns nil when the experiment flag is off" do
      Flipper.disable( FeatureFlagging.experiment_flag( experiment ) )
      expect( FeatureFlagging.variant( experiment, actor ) ).to be_nil
    end

    it "returns one of the variants" do
      expect( FeatureFlagging::VARIANTS ).to include FeatureFlagging.variant( experiment, actor )
    end

    it "is stable for the same actor" do
      first = FeatureFlagging.variant( experiment, actor )
      expect( 3.times.map { FeatureFlagging.variant( experiment, actor ) } ).to all( eq first )
    end

    it "returns nil for anonymous callers" do
      expect( FeatureFlagging.variant( experiment, nil ) ).to be_nil
    end

    it "is nil and warns for an experiment whose flag does not exist" do
      allow( Rails.logger ).to receive( :warn )
      expect( FeatureFlagging.variant( :not_a_real_experiment, actor ) ).to be_nil
      expect( Rails.logger ).to have_received( :warn ).with( /exp_not_a_real_experiment/ )
    end

    it "splits actors roughly evenly across variants" do
      counts = fake_actors( 1000 ).
        map {| a | FeatureFlagging.variant( experiment, a ) }.
        tally
      expect( counts.keys ).to match_array FeatureFlagging::VARIANTS
      counts.each_value {| n | expect( n ).to be_between( 400, 600 ) }
    end

    # Regression: CRC32 linearity caused perfect anti-correlation (0% cross-test agreement).
    it "assigns variants independently of other experiments" do
      other = :hello_world_two
      Flipper.enable( FeatureFlagging.experiment_flag( other ) )
      actors = fake_actors( 1000 )
      agreements = actors.count do | a |
        FeatureFlagging.variant( experiment, a ) == FeatureFlagging.variant( other, a )
      end
      expect( agreements ).to be_between( 420, 580 )
    end
  end

  describe "experiments_for" do
    it "returns a variant per experiment flag, keyed by experiment name" do
      Flipper.enable( FeatureFlagging.experiment_flag( experiment ) )
      map = FeatureFlagging.experiments_for( actor )
      expect( map.keys ).to eq [experiment]
      expect( map[experiment] ).to be_present
    end

    it "returns nil variants when the experiment flags are off" do
      expect( FeatureFlagging.experiments_for( actor ).values ).to all( be_nil )
    end

    it "sees an experiment created at runtime" do
      Flipper.add( :exp_brand_new )
      expect( FeatureFlagging.experiments_for( actor ).keys ).to eq %i[brand_new hello_world]
    end

    it "is empty when no experiments exist" do
      Flipper.remove( FeatureFlagging.experiment_flag( experiment ) )
      expect( FeatureFlagging.experiments_for( actor ) ).to eq( {} )
    end
  end

  describe "under adapter failure" do
    before do
      allow( Rails.logger ).to receive( :error )
      allow( Rails.logger ).to receive( :warn )
      Flipper.instance = Flipper.new( FeatureFlagging::FailClosedAdapter.new( raising_adapter ) )
    end

    it "reads every flag as off" do
      expect( FeatureFlagging.enabled?( flag, actor ) ).to be false
    end

    it "sends no flags or experiments rather than raising" do
      expect( FeatureFlagging.flags_for( actor ) ).to eq( {} )
      expect( FeatureFlagging.experiments_for( actor ) ).to eq( {} )
    end
  end

  describe "percentage of actors rollout" do
    let( :actors ) { fake_actors( 500 ) }

    def enabled_ids
      actors.select {| a | FeatureFlagging.enabled?( flag, a ) }.map( &:flipper_id )
    end

    it "is deterministic across repeated evaluations" do
      Flipper.enable_percentage_of_actors( flag, 25 )
      expect( enabled_ids ).to eq enabled_ids
    end

    it "enables roughly the requested percentage" do
      Flipper.enable_percentage_of_actors( flag, 25 )
      expect( enabled_ids.size ).to be_between( 100, 150 )
    end

    it "only ever adds actors as the percentage rises" do
      Flipper.enable_percentage_of_actors( flag, 10 )
      at_ten = enabled_ids
      Flipper.enable_percentage_of_actors( flag, 30 )
      at_thirty = enabled_ids
      expect( at_ten ).not_to be_empty
      expect( at_thirty.size ).to be > at_ten.size
      expect( at_ten - at_thirty ).to be_empty
    end

    it "removes everyone when rolled back" do
      Flipper.enable_percentage_of_actors( flag, 50 )
      expect( enabled_ids ).not_to be_empty
      Flipper.disable( flag )
      expect( enabled_ids ).to be_empty
    end
  end

  # Memory adapter tested above; this verifies production storage stack over real tables.
  describe "the ActiveRecord adapter" do
    let( :ar_flipper ) { Flipper.new( FeatureFlagging.build_adapter( cache: nil ) ) }

    it "reads back through the stack" do
      expect( ar_flipper.enabled?( flag ) ).to be false
      ar_flipper.enable( flag )
      expect( ar_flipper.enabled?( flag ) ).to be true
    end

    it "persists a percentage gate to flipper_gates" do
      ar_flipper.enable_percentage_of_actors( flag, 42 )
      gates = ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array(
          ["SELECT key, value FROM flipper_gates WHERE feature_key = ?", flag.to_s]
        )
      ).to_a
      expect( gates ).to eq [{ "key" => "percentage_of_actors", "value" => "42" }]
    end

    it "persists an actor gate to flipper_gates" do
      ar_flipper.enable_actor( flag, actor )
      values = ActiveRecord::Base.connection.select_values(
        ActiveRecord::Base.sanitize_sql_array(
          ["SELECT value FROM flipper_gates WHERE feature_key = ? AND key = ?", flag.to_s, "actors"]
        )
      )
      expect( values ).to eq ["User;#{actor.id}"]
    end

    it "registers the feature in flipper_features" do
      ar_flipper.enable( flag )
      keys = ActiveRecord::Base.connection.select_values( "SELECT key FROM flipper_features" )
      expect( keys ).to eq [flag.to_s]
    end
  end
end
