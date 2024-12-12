# frozen_string_literal: true

require "spec_helper"

shared_examples "BlockedIp Middleware using header" do | header |
  it "non blocked IP should access page" do
    get "/ping", headers: { header => "192.168.0.1" }
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "status"
  end

  it "blocked IP should not access page" do
    blocked_ip = BlockedIp.make!
    Rails.cache.delete( "blocked_ips" )
    get "/ping", headers: { header => blocked_ip.ip }
    expect( response.response_code ).to eq 403
    expect( response.body ).to include "Forbidden"
  end

  it "cache is used, so new blocked IP should still access page" do
    blocked_ip = BlockedIp.make!
    get "/ping", headers: { header => blocked_ip.ip }
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "status"
  end

  it "unblock IP should access page again" do
    blocked_ip = BlockedIp.make!
    ip = blocked_ip.ip
    Rails.cache.delete( "blocked_ips" )
    get "/ping", headers: { header => ip }
    expect( response.response_code ).to eq 403
    expect( response.body ).to include "Forbidden"
    blocked_ip.delete
    Rails.cache.delete( "blocked_ips" )
    get "/ping", headers: { header => ip }
    expect( response.response_code ).to eq 200
    expect( response.body ).to include "status"
  end
end

describe "BlockedIp Middleware", type: :request do
  include_examples "BlockedIp Middleware using header", "HTTP_X_FORWARDED_ORIGINAL_FOR"
  include_examples "BlockedIp Middleware using header", "HTTP_X_FORWARDED_FOR"
  include_examples "BlockedIp Middleware using header", "HTTP_X_CLUSTER_CLIENT_IP"
  include_examples "BlockedIp Middleware using header", "REMOTE_ADDR"
end
