require "spec_helper"

describe ActsAsVotable::Vote do

  it "associated with proper votables" do
    u = User.make!
    obs = Observation.make!(id: 100)
    ident = Identification.make!(id: 100)
    u.vote_up_for(obs)
    u.vote_up_for(ident)
    expect( obs.id ).to eq ident.id
    # first vote has an obs, not an ident, even though they have the same ID
    expect( ActsAsVotable::Vote.first.observation ).to eq obs
    expect( ActsAsVotable::Vote.first.identification ).to be_nil
    # first vote has an ident, not an obs
    expect( ActsAsVotable::Vote.last.observation ).to be_nil
    expect( ActsAsVotable::Vote.last.identification ).to eq ident
  end


end
