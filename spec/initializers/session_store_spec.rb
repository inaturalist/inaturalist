# frozen_string_literal: true

require "spec_helper"

describe "Active Record session commit durability" do
  around( :each ) do | example |
    DatabaseCleaner.strategy = :truncation
    example.run
    DatabaseCleaner.strategy = :transaction
  end

  let( :session_class ) do
    ActionDispatch::Session::ActiveRecordStore.session_class
  end

  let( :store ) do
    ActionDispatch::Session::ActiveRecordStore.new(
      ->( _env ) { [200, {}, []] },
      key: "_session_store_spec"
    )
  end

  let( :created_session_ids ) { [] }

  after do
    return unless created_session_ids.any?

    session_class.where(
      session_id: created_session_ids
    ).delete_all
  end

  def build_request
    env = Rack::MockRequest.env_for( "/" )
    env[Rack::RACK_SESSION_OPTIONS] = { id: nil }

    ActionDispatch::Request.new( env )
  end

  def capture_sql
    statements = []

    subscriber = lambda do | _name, _start, _finish, _id, payload |
      statements << payload[:sql] unless payload[:name] == "SCHEMA"
    end

    ActiveSupport::Notifications.subscribed(
      subscriber,
      "sql.active_record"
    ) do
      yield
    end

    statements
  end

  it "sets synchronous_commit to off for session inserts and updates" do
    request = build_request
    sid = nil

    insert_sql = capture_sql do
      sid, = store.send( :find_session, request, nil )
      created_session_ids << sid.private_id
    end

    set_local_index = insert_sql.index(
      "SET LOCAL synchronous_commit = off"
    )
    insert_index = insert_sql.index do | statement |
      statement.match?( /\AINSERT\b/i )
    end

    expect( set_local_index ).not_to be_nil
    expect( insert_index ).not_to be_nil
    expect( set_local_index ).to be < insert_index

    update_sql = capture_sql do
      result = store.send(
        :write_session,
        request,
        sid,
        { "integration_test" => true },
        {}
      )

      expect( result ).to eq( sid )
    end

    set_local_index = update_sql.index(
      "SET LOCAL synchronous_commit = off"
    )
    update_index = update_sql.index do | statement |
      statement.match?( /\AUPDATE\b/i )
    end

    expect( set_local_index ).not_to be_nil
    expect( update_index ).not_to be_nil
    expect( set_local_index ).to be < update_index
  end
end
