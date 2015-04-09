require "spec_helper"

describe "Delayed::Jobs::unique_hash" do

  it "allows a unique_hash to be set" do
    expect( Delayed::Job.count ).to eq 0
    User.delay(unique_hash: "itworks").find(1)
    expect( Delayed::Job.count ).to eq 1
    expect( Delayed::Job.first.unique_hash ).to eq "itworks"
  end

  it "allows only one just unique_hash to be set" do
    expect( Delayed::Job.count ).to eq 0
    User.delay(unique_hash: "first!").find(1)
    User.delay(unique_hash: "first!").find(2)
    User.delay(unique_hash: "third").find(3)
    expect( Delayed::Job.count ).to eq 2
    expect( Delayed::Job.all[0].unique_hash ).to eq "first!"
    expect( Delayed::Job.all[1].unique_hash ).to eq "third"
  end

end
