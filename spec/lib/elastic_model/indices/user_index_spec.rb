require "spec_helper"

describe "User Index" do
  let( :user ) { User.make! }
  
  it "should index as spam if user is spam" do
    expect( user.as_indexed_json[:spam] ).to be false
    Flag.make!( flag: Flag::SPAM, flaggable: user )
    user.reload
    expect( user ).to be_known_spam
    expect( user.as_indexed_json[:spam] ).to be true
  end

  it "should index whether the user was suspended" do
    expect( user.as_indexed_json[:suspended] ).to be false
    user.suspend!
    expect( user.as_indexed_json[:suspended] ).to be true
  end  
end
