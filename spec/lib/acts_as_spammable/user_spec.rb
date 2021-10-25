require "spec_helper"

describe User, "spam" do

  it "flags users with a high spam count as spammers" do
    u = User.make!
    expect(u.spammer?).to be false
    3.times{ Flag.make!(flaggable: Observation.make!(user: u), flag: Flag::SPAM) }
    u.reload
    expect(u.spammer?).to be true
  end

  it "suspends spammers" do
    u = User.make!
    expect(u.suspended_at).to be_nil
    3.times{ Flag.make!(flaggable: Observation.make!(user: u), flag: Flag::SPAM) }
    u.reload
    expect(u.suspended_at).to_not be_nil
  end

  it "knows what content has been flagged as spam" do
    u = User.make!
    expect(u.content_flagged_as_spam.count).to be 0
    3.times{ Flag.make!(flaggable: Observation.make!(user: u), flag: Flag::SPAM) }
    expect(u.content_flagged_as_spam.count).to be 3
  end

  it "doesn't count resolved flags toward spam content" do
    u = User.make!
    expect(u.content_flagged_as_spam.count).to be 0
    3.times{ Flag.make!(flaggable: Observation.make!(user: u), flag: Flag::SPAM) }
    expect(u.content_flagged_as_spam.count).to be 3
    Flag.last.update_column(:resolved, true)
    expect(u.content_flagged_as_spam.count).to be 2
  end

  it "updates spam count when content is flagged" do
    u = User.make!
    expect(u.spam_count).to be 0
    3.times{ Flag.make!(flaggable: Observation.make!(user: u), flag: Flag::SPAM) }
    u.reload
    expect(u.spam_count).to be 3
  end

  it "decrements spam count when flags are resolved" do
    u = User.make!
    expect(u.spam_count).to be 0
    3.times{ Flag.make!(flaggable: Observation.make!(user: u), flag: Flag::SPAM) }
    u.reload
    expect(u.spam_count).to be 3
    Flag.last.update(resolved: true, resolver: u)
    u.reload
    expect(u.content_flagged_as_spam.count).to be 2
  end

  it "knows all the spam flags on a users content" do
    u = User.make!
    expect(u.flags_on_spam_content.count).to eq 0
    3.times do
      obs = Observation.make!(user: u)
      Flag.make!(flaggable: obs, flag: Flag::SPAM)
      Flag.make!(flaggable: obs, flag: "something else")
    end
    expect(u.flags_on_spam_content.count).to eq 3
  end

  it "does not consider spam flags on a user a flag on another users content" do
    u = User.make!
    u2 = User.make!
    Flag.make!(flaggable: u2, flag: Flag::SPAM)
    expect(u.flags_on_spam_content.count).to eq 0
  end

  it "does not check for spam if description is blank" do
    u = User.make(email: 'foo+bar20150301@inaturalist.org')
    expect(u.description).to be_blank
    expect(u).to_not receive(:spam?)
    u.save
    expect(u).not_to be_flagged_as_spam
    expect(u).not_to be_suspended
    expect(u).not_to be_spammer
  end

  describe "set_as_non_spammer_if_meets_criteria" do
    it "should set spammer to false after 3 research grade observations" do
      u = User.make!
      make_research_grade_observation( user: u )
      expect( u.spammer ).to be nil
      make_research_grade_observation( user: u )
      expect( u.spammer ).to be nil
      make_research_grade_observation( user: u )
      u.reload
      expect( u.spammer ).to be false
    end
  end
end
