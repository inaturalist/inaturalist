# frozen_string_literal: true

require "spec_helper"

describe UserSignup do
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_uniqueness_of( :user_id ) }
  it { is_expected.to validate_presence_of( :browser_id ) }
  it { is_expected.to validate_presence_of( :ip ) }

  describe "validations" do
    it "is valid" do
      user = create( :user )
      user_signup = build( :user_signup, user: user, browser_id: "browser123", ip: "192.168.1.1" )
      expect( user_signup ).to be_valid
    end

    it "is invalid with an incorrect IP format" do
      user = create( :user )
      user_signup = build( :user_signup, user: user, browser_id: "browser123", ip: "invalid_ip" )
      expect( user_signup ).to be_invalid
    end

    it "is invalid without IP" do
      user = create( :user )
      user_signup = build( :user_signup, user: user, browser_id: "browser123", ip: nil )
      expect( user_signup ).to be_invalid
    end

    it "is invalid without browser ID" do
      user = create( :user )
      user_signup = build( :user_signup, user: user, browser_id: nil, ip: "192.168.1.1" )
      expect( user_signup ).to be_invalid
    end
  end

  describe "VPN status" do
    let( :vpn_checker ) { instance_double( VPNChecker ) }

    before do
      allow( VPNChecker ).to receive( :new ).and_return( vpn_checker )
    end

    it "sets vpn to true if IP is in VPN range" do
      allow( vpn_checker ).to receive( :ip_in_vpn_range? ).with( "192.168.1.1" ).and_return( true )
      signup = build( :user_signup, ip: "192.168.1.1" )
      signup.validate
      expect( signup.vpn ).to be true
    end

    it "sets vpn to false if IP is not in VPN range" do
      allow( vpn_checker ).to receive( :ip_in_vpn_range? ).with( "192.168.1.1" ).and_return( false )
      signup = build( :user_signup, ip: "192.168.1.1" )
      signup.validate
      expect( signup.vpn ).to be false
    end
  end

  describe "Root user by IP" do
    it "Matching IP in the last 5 days" do
      previous_signup = create( :user_signup, ip: "192.168.1.1", created_at: 3.days.ago )
      new_signup = build( :user_signup, ip: "192.168.1.1" )
      new_signup.validate
      expect( new_signup.root_user_id_by_ip ).to eq( previous_signup.user_id )
    end

    it "Matching IP older than the last 5 days" do
      create( :user_signup, ip: "192.168.1.1", created_at: 15.days.ago )
      new_signup = build( :user_signup, ip: "192.168.1.1" )
      new_signup.validate
      expect( new_signup.root_user_id_by_ip ).to be_nil
    end

    it "No matching IP" do
      create( :user_signup, ip: "192.168.1.2" )
      new_signup = build( :user_signup, ip: "192.168.1.1" )
      new_signup.validate
      expect( new_signup.root_user_id_by_ip ).to be_nil
    end
  end

  describe "Root user by Browser ID" do
    it "Matching Browser ID" do
      previous_signup = create( :user_signup, browser_id: "browser123" )
      new_signup = build( :user_signup, browser_id: "browser123" )
      new_signup.validate
      expect( new_signup.root_user_id_by_browser_id ).to eq( previous_signup.user_id )
    end

    it "No matching Browser ID" do
      create( :user_signup, browser_id: "browser456" )
      new_signup = build( :user_signup, browser_id: "browser123" )
      new_signup.validate
      expect( new_signup.root_user_id_by_browser_id ).to be_nil
    end
  end
end
