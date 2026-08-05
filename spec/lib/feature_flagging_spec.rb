# frozen_string_literal: true

require "spec_helper"

describe FeatureFlagging do
  let( :flag ) { :flipper_smoke_test }
  let( :experiment ) { :hello_world }
  let( :actor ) { User.make! }

  # Cheap stand-ins for bucketing tests, so we don't insert hundreds of users
  def fake_actors( count )
    klass = Struct.new( :flipper_id )
    ( 1..count ).map {| i | klass.new( "User;#{i}" ) }
  end

  describe "the declared flags" do
    it "includes the pilot flag" do
      expect( FeatureFlagging::KNOWN_FLAGS ).to have_key flag
    end

    it "sends the pilot flag to clients" do
      expect( FeatureFlagging::CLIENT_FLAGS ).to include flag
    end

    it "only sends declared flags to clients" do
      expect( FeatureFlagging::CLIENT_FLAGS - FeatureFlagging::KNOWN_FLAGS.keys ).to be_empty
    end

    it "declares a flag for every experiment" do
      FeatureFlagging::KNOWN_EXPERIMENTS.each_key do | key |
        expect( FeatureFlagging::KNOWN_FLAGS ).to have_key FeatureFlagging.experiment_flag( key )
      end
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

    it "raises for a flag that has not been declared" do
      expect { FeatureFlagging.enabled?( :not_a_real_flag, actor ) }.
        to raise_error FeatureFlagging::UnknownFlagError
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

    # Devise::Strategies::ApplicationJsonWebToken hands ApplicationController a
    # User.new( id: -1 ) for application-token requests, which is how a
    # logged-out mobile client arrives. It has a flipper_id ( "User;-1" ), so
    # without an explicit guard the entire logged-out mobile population would
    # share one bucket and a percentage gate would resolve to 0% or 100% of it.
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
    it "returns a boolean for every client flag" do
      map = FeatureFlagging.flags_for( actor )
      expect( map.keys ).to eq FeatureFlagging::CLIENT_FLAGS
      expect( map.values ).to all( be false )
    end

    it "reflects an enabled flag" do
      Flipper.enable_actor( flag, actor )
      expect( FeatureFlagging.flags_for( actor )[flag] ).to be true
      expect( FeatureFlagging.flags_for( nil )[flag] ).to be false
    end

    it "serializes to a JSON object of booleans" do
      parsed = JSON.parse( FeatureFlagging.flags_for( actor ).to_json )
      expect( parsed.keys ).to eq FeatureFlagging::CLIENT_FLAGS.map( &:to_s )
      expect( parsed.values ).to all( be false )
    end
  end

  describe "variant" do
    before { Flipper.enable( FeatureFlagging.experiment_flag( experiment ) ) }

    it "returns nil when the experiment flag is off" do
      Flipper.disable( FeatureFlagging.experiment_flag( experiment ) )
      expect( FeatureFlagging.variant( experiment, actor ) ).to be_nil
    end

    it "returns one of the declared variants" do
      expect( FeatureFlagging::KNOWN_EXPERIMENTS[experiment] ).
        to include FeatureFlagging.variant( experiment, actor )
    end

    it "is stable for the same actor" do
      first = FeatureFlagging.variant( experiment, actor )
      expect( 3.times.map { FeatureFlagging.variant( experiment, actor ) } ).to all( eq first )
    end

    it "returns nil for anonymous callers" do
      expect( FeatureFlagging.variant( experiment, nil ) ).to be_nil
    end

    it "raises for an experiment that has not been declared" do
      expect { FeatureFlagging.variant( :not_a_real_experiment, actor ) }.
        to raise_error FeatureFlagging::UnknownExperimentError
    end

    it "splits actors roughly evenly across variants" do
      counts = fake_actors( 1000 ).
        map {| a | FeatureFlagging.variant( experiment, a ) }.
        tally
      expect( counts.keys ).to match_array FeatureFlagging::KNOWN_EXPERIMENTS[experiment]
      counts.each_value {| n | expect( n ).to be_between( 400, 600 ) }
    end

    # Regression test. The parity target groups in Announcement put the same
    # users in the same bucket for every test, which this is meant to avoid.
    # An earlier CRC32 implementation failed this catastrophically -- because
    # CRC32 is linear, agreement was 0 of 500: every actor assigned "control"
    # here was assigned "treatment" there. Any correlated hash fails this.
    it "assigns variants independently of other experiments" do
      other = :hello_world_two
      stub_const_experiments( other => %w(control treatment) )
      Flipper.enable( FeatureFlagging.experiment_flag( other ) )
      actors = fake_actors( 1000 )
      agreements = actors.count do | a |
        FeatureFlagging.variant( experiment, a ) == FeatureFlagging.variant( other, a )
      end
      expect( agreements ).to be_between( 420, 580 )
    end
  end

  describe "experiments_for" do
    it "returns a variant per declared experiment" do
      Flipper.enable( FeatureFlagging.experiment_flag( experiment ) )
      map = FeatureFlagging.experiments_for( actor )
      expect( map.keys ).to eq FeatureFlagging::KNOWN_EXPERIMENTS.keys
      expect( map[experiment] ).to be_present
    end

    it "returns nil variants when the experiment flags are off" do
      expect( FeatureFlagging.experiments_for( actor ).values ).to all( be_nil )
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

  # Everything above runs against the memory adapter configured in spec_helper.
  # This proves the migration in db/structure.sql actually backs it.
  describe "the ActiveRecord adapter" do
    let( :ar_flipper ) { Flipper.new( Flipper::Adapters::ActiveRecord.new ) }

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

  private

  # Temporarily add experiments without mutating the frozen constant
  def stub_const_experiments( extra )
    stub_const(
      "FeatureFlagging::KNOWN_EXPERIMENTS",
      FeatureFlagging::KNOWN_EXPERIMENTS.merge( extra ).freeze
    )
    stub_const(
      "FeatureFlagging::KNOWN_FLAGS",
      FeatureFlagging::KNOWN_FLAGS.merge(
        extra.keys.index_with {| k | "test experiment #{k}" }.
          transform_keys {| k | FeatureFlagging.experiment_flag( k ) }
      ).freeze
    )
  end
end
