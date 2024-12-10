# frozen_string_literal: true

require "spec_helper"

describe BlockedIp, type: :request do
  before( :all ) do
    BlockedIp.destroy_all
  end

  it "non blocked IP should access page" do
    get "/ping", headers: { "REMOTE_ADDR" => "192.168.0.1" }
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "status"
  end

  it "blocked IP should not access page" do
    BlockedIp.create!( ip: "192.168.0.2" )
    Rails.cache.delete( "blocked_ips" )
    get "/ping", headers: { "REMOTE_ADDR" => "192.168.0.2" }
    expect( response.response_code ).to eq 403
    expect( response.body ).to include "Forbidden"
  end

  it "cache is used, so new blocked IP should still access page" do
    BlockedIp.create!( ip: "192.168.0.3" )
    get "/ping", headers: { "REMOTE_ADDR" => "192.168.0.3" }
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "status"
  end

  it "unblock IP should access page again" do
    BlockedIp.create!( ip: "192.168.0.4" )
    Rails.cache.delete( "blocked_ips" )
    get "/ping", headers: { "REMOTE_ADDR" => "192.168.0.4" }
    expect( response.response_code ).to eq 403
    expect( response.body ).to include "Forbidden"
    BlockedIp.where( ip: "192.168.0.4" ).delete_all
    Rails.cache.delete( "blocked_ips" )
    get "/ping", headers: { "REMOTE_ADDR" => "192.168.0.4" }
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "status"
  end
end
