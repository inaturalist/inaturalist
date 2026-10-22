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

  # Logged-out apps send X-Installation-ID; install_ flags bucket on it so logging in changes nothing.
  describe "installation-scoped flags" do
    let( :installation_id ) { SecureRandom.uuid }
    let( :install_flag ) { :client_install_smoke_test }
    let( :install_experiment ) { :install_hello_world }
    let( :anonymous_user ) do
      User.new( id: Devise::Strategies::ApplicationJsonWebToken::ANONYMOUS_USER_ID, login: "anonymous" )
    end

    before { add_install_test_flags }

    def installation_ids( count )
      Array.new( count ) { SecureRandom.uuid }
    end

    # What an admin types into Flipper UI's actor field.
    def installation_actor( id )
      Flipper::Actor.new( "Installation;#{id}" )
    end

    describe "classification" do
      it "recognizes the install_ marker after the client_ or exp_ prefix" do
        expect( FeatureFlagging.install_scoped?( "client_install_thing" ) ).to be true
        expect( FeatureFlagging.install_scoped?( :exp_install_thing ) ).to be true
      end

      it "keeps the prefix kind" do
        expect( FeatureFlagging.kind_of( "client_install_thing" ) ).to eq :client
        expect( FeatureFlagging.kind_of( "exp_install_thing" ) ).to eq :experiment
      end

      it "ignores a bare marker, a server key, a mis-cased key, and a longer word" do
        %w(client_install_ exp_install_ install_thing server_install_thing
           Client_install_thing exp_Install_thing exp_installer_thing client_thing).each do | key |
          expect( FeatureFlagging.install_scoped?( key ) ).to be( false ), key
        end
      end

      it "describes installation bucketing for the admin UI" do
        expect( FeatureFlagging.description_for( "exp_install_b" ) ).
          not_to eq FeatureFlagging.description_for( "exp_b" )
        expect( FeatureFlagging.description_for( "client_install_a" ) ).
          not_to eq FeatureFlagging.description_for( "client_a" )
      end
    end

    describe "installation ids" do
      it "accepts a uuid in either case" do
        expect( FeatureFlagging.valid_installation_id?( installation_id ) ).to be true
        expect( FeatureFlagging.valid_installation_id?( installation_id.upcase ) ).to be true
      end

      it "rejects anything else" do
        [nil, "", "installation123", "#{installation_id}\nx", " #{installation_id}", "#{installation_id}0"].
          each do | value |
          expect( FeatureFlagging.valid_installation_id?( value ) ).to be( false ), value.inspect
        end
      end

      it "buckets by pinned flipper_ids" do
        request = FeatureFlagging::RequestActor.new( actor, installation_id )
        expect( request.bucketed_by( :installation ).flipper_id ).to eq "Installation;#{installation_id}"
        expect( request.bucketed_by( :user ).flipper_id ).to eq "User;#{actor.id}"
        expect( request.flipper_ids ).to eq ["User;#{actor.id}", "Installation;#{installation_id}"]
      end

      it "has no bucketing actor for a missing identity" do
        expect( FeatureFlagging::RequestActor.new( nil, installation_id ).bucketed_by( :user ) ).to be_nil
        expect( FeatureFlagging::RequestActor.new( actor, nil ).bucketed_by( :installation ) ).to be_nil
      end
    end

    describe "a logged-out app" do
      it "picks up a percentage gate" do
        Flipper.enable_percentage_of_actors( install_flag, 100 )
        expect( FeatureFlagging.enabled?( install_flag, nil, installation_id: installation_id ) ).to be true
        expect( FeatureFlagging.enabled?( install_flag, anonymous_user, installation_id: installation_id ) ).
          to be true
      end

      it "picks up an actor gate on its installation" do
        Flipper.enable_actor( install_flag, installation_actor( installation_id ) )
        expect( FeatureFlagging.enabled?( install_flag, nil, installation_id: installation_id ) ).to be true
        expect( FeatureFlagging.enabled?( install_flag, nil, installation_id: SecureRandom.uuid ) ).to be false
      end

      it "is assigned a variant" do
        Flipper.enable( FeatureFlagging.experiment_flag( install_experiment ) )
        expect( FeatureFlagging::VARIANTS ).
          to include FeatureFlagging.variant( install_experiment, nil, installation_id: installation_id )
      end

      it "is still not bucketed for a user-scoped flag" do
        Flipper.enable_percentage_of_actors( flag, 100 )
        Flipper.enable( FeatureFlagging.experiment_flag( experiment ) )
        expect( FeatureFlagging.enabled?( flag, anonymous_user, installation_id: installation_id ) ).to be false
        expect( FeatureFlagging.variant( experiment, nil, installation_id: installation_id ) ).to be_nil
      end
    end

    describe "without a valid installation id" do
      it "has no actor for an install-scoped flag, signed in or not" do
        Flipper.enable_percentage_of_actors( install_flag, 100 )
        expect( FeatureFlagging.enabled?( install_flag ) ).to be false
        expect( FeatureFlagging.enabled?( install_flag, actor ) ).to be false
        expect( FeatureFlagging.enabled?( install_flag, actor, installation_id: "installation123" ) ).to be false
      end

      it "still follows the boolean gate" do
        Flipper.enable( install_flag )
        expect( FeatureFlagging.enabled?( install_flag ) ).to be true
      end
    end

    # WEB-1396 scenario 2: logging in must not move an installation to another bucket.
    describe "logging in" do
      let( :ids ) { installation_ids( 200 ) }

      it "keeps every installation's percentage result" do
        Flipper.enable_percentage_of_actors( install_flag, 50 )
        results = [nil, anonymous_user, actor].map do | caller |
          ids.map {| id | FeatureFlagging.enabled?( install_flag, caller, installation_id: id ) }
        end
        expect( results[0] ).to include( true, false )
        expect( results.uniq.size ).to eq 1
      end

      it "keeps every installation's variant" do
        Flipper.enable( FeatureFlagging.experiment_flag( install_experiment ) )
        results = [nil, anonymous_user, actor].map do | caller |
          ids.map {| id | FeatureFlagging.variant( install_experiment, caller, installation_id: id ) }
        end
        expect( results[0] ).to include( *FeatureFlagging::VARIANTS )
        expect( results.uniq.size ).to eq 1
      end
    end

    describe "a signed-in app" do
      it "still matches an actor gate on the user" do
        Flipper.enable_actor( install_flag, actor )
        expect( FeatureFlagging.enabled?( install_flag, actor, installation_id: installation_id ) ).to be true
        expect( FeatureFlagging.enabled?( install_flag, nil, installation_id: installation_id ) ).to be false
      end

      it "still matches the admins group" do
        Flipper.enable_group( install_flag, :admins )
        expect( FeatureFlagging.enabled?( install_flag, make_admin, installation_id: installation_id ) ).to be true
        expect( FeatureFlagging.enabled?( install_flag, actor, installation_id: installation_id ) ).to be false
        expect( FeatureFlagging.enabled?( install_flag, nil, installation_id: installation_id ) ).to be false
      end

      it "buckets a user-scoped flag by the user, ignoring the installation" do
        Flipper.enable( FeatureFlagging.experiment_flag( experiment ) )
        Flipper.enable_actor( flag, actor )
        expect( FeatureFlagging.enabled?( flag, actor, installation_id: installation_id ) ).to be true
        installation_ids( 20 ).each do | id |
          expect( FeatureFlagging.variant( experiment, actor, installation_id: id ) ).
            to eq FeatureFlagging.variant( experiment, actor )
        end
      end
    end

    # Flipper only sees the key's bucketing id, so the other identity is matched separately.
    describe "targeting the identity a key does not bucket by" do
      it "enables a user-scoped flag for a targeted installation, logged in or out" do
        Flipper.enable_actor( flag, installation_actor( installation_id ) )
        expect( FeatureFlagging.enabled?( flag, nil, installation_id: installation_id ) ).to be true
        expect( FeatureFlagging.enabled?( flag, actor, installation_id: installation_id ) ).to be true
        expect( FeatureFlagging.enabled?( flag, nil, installation_id: SecureRandom.uuid ) ).to be false
        expect( FeatureFlagging.enabled?( flag, actor ) ).to be false
      end

      it "enables an install-scoped flag for a targeted user without the app header" do
        Flipper.enable_actor( install_flag, actor )
        expect( FeatureFlagging.enabled?( install_flag, actor ) ).to be true
        expect( FeatureFlagging.flags_for( actor )[install_flag] ).to be true
        expect( FeatureFlagging.enabled?( install_flag, User.make! ) ).to be false
      end

      it "enables an install-scoped flag for admins without the app header" do
        Flipper.enable_group( install_flag, :admins )
        expect( FeatureFlagging.enabled?( install_flag, make_admin ) ).to be true
        expect( FeatureFlagging.enabled?( install_flag, actor ) ).to be false
      end

      it "enrolls a targeted installation in a user experiment but only assigns a variant when signed in" do
        Flipper.enable_actor( FeatureFlagging.experiment_flag( experiment ), installation_actor( installation_id ) )
        expect( FeatureFlagging.variant( experiment, nil, installation_id: installation_id ) ).to be_nil
        assigned = FeatureFlagging.variant( experiment, actor, installation_id: installation_id )
        expect( FeatureFlagging::VARIANTS ).to include assigned
        Flipper.enable( FeatureFlagging.experiment_flag( experiment ) )
        expect( assigned ).to eq FeatureFlagging.variant( experiment, actor )
      end

      it "enrolls a targeted user in an installation experiment but only assigns a variant with the header" do
        Flipper.enable_actor( FeatureFlagging.experiment_flag( install_experiment ), actor )
        expect( FeatureFlagging.variant( install_experiment, actor ) ).to be_nil
        expect( FeatureFlagging.variant( install_experiment, nil, installation_id: installation_id ) ).to be_nil
        assigned = FeatureFlagging.variant( install_experiment, actor, installation_id: installation_id )
        expect( FeatureFlagging::VARIANTS ).to include assigned
        Flipper.enable( FeatureFlagging.experiment_flag( install_experiment ) )
        expect( assigned ).to eq FeatureFlagging.variant( install_experiment, nil, installation_id: installation_id )
      end

      it "enrolls admins in an installation experiment but only assigns a variant with the header" do
        Flipper.enable_group( FeatureFlagging.experiment_flag( install_experiment ), :admins )
        admin = make_admin
        expect( FeatureFlagging.variant( install_experiment, admin ) ).to be_nil
        expect( FeatureFlagging::VARIANTS ).
          to include FeatureFlagging.variant( install_experiment, admin, installation_id: installation_id )
      end

      it "does not let a targeted identity widen a percentage gate" do
        Flipper.enable_percentage_of_actors( flag, 100 )
        Flipper.enable_percentage_of_actors( install_flag, 100 )
        expect( FeatureFlagging.enabled?( flag, nil, installation_id: installation_id ) ).to be false
        expect( FeatureFlagging.enabled?( install_flag, actor ) ).to be false
      end
    end

    it "splits installations roughly evenly across variants" do
      Flipper.enable( FeatureFlagging.experiment_flag( install_experiment ) )
      counts = installation_ids( 1000 ).
        map {| id | FeatureFlagging.variant( install_experiment, nil, installation_id: id ) }.
        tally
      expect( counts.keys ).to match_array FeatureFlagging::VARIANTS
      counts.each_value {| n | expect( n ).to be_between( 400, 600 ) }
    end

    it "enables roughly the requested percentage of installations" do
      Flipper.enable_percentage_of_actors( install_flag, 25 )
      enabled = installation_ids( 500 ).count do | id |
        FeatureFlagging.enabled?( install_flag, nil, installation_id: id )
      end
      expect( enabled ).to be_between( 100, 150 )
    end

    it "resolves both kinds in the client maps" do
      Flipper.enable_percentage_of_actors( install_flag, 100 )
      Flipper.enable_percentage_of_actors( flag, 100 )
      Flipper.enable( FeatureFlagging.experiment_flag( install_experiment ) )
      Flipper.enable( FeatureFlagging.experiment_flag( experiment ) )
      flags = FeatureFlagging.flags_for( nil, installation_id: installation_id )
      experiments = FeatureFlagging.experiments_for( nil, installation_id: installation_id )
      expect( flags ).to eq( client_install_smoke_test: true, client_smoke_test: false )
      expect( experiments[experiment] ).to be_nil
      expect( FeatureFlagging::VARIANTS ).to include experiments[install_experiment]
    end
  end

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
