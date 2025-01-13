require "spec_helper"

describe BlockedIp do
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_uniqueness_of( :ip ) }

  it "is valid with a user and correctly formatted IP" do
    user = create( :user )
    blocked_ip = BlockedIp.new( user: user, ip: "192.168.1.1" )
    expect( blocked_ip ).to be_valid
  end

  it "is invalid without a user" do
    blocked_ip = BlockedIp.new( user: nil, ip: "192.168.1.1" )
    expect( blocked_ip ).to be_invalid
  end

  it "is invalid with a non-unique IP" do
    user1 = create( :user )
    create( :blocked_ip, user: user1, ip: "192.168.1.1" )
    user2 = create( :user )
    duplicate_ip = BlockedIp.new( user: user2, ip: "192.168.1.1" )
    expect( duplicate_ip ).to be_invalid
  end

  it "is invalid with an incorrectly formatted IP" do
    user = create( :user )
    invalid_ip = BlockedIp.new( user: user, ip: "invalid-ip" )
    expect( invalid_ip ).to be_invalid
  end

  it "is invalid with an out of range IP" do
    user = create( :user )
    invalid_ip = BlockedIp.new( user: user, ip: "555.555.555.555" )
    expect( invalid_ip ).to be_invalid
  end

  it "is invalid when the IP is nil" do
    user = create( :user )
    blocked_ip = BlockedIp.new( user: user, ip: nil )
    expect( blocked_ip ).to be_invalid
  end
end
