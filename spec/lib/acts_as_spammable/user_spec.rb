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
    Flag.last.update_attributes(resolved: true, resolver: u)
    u.reload
    expect(u.content_flagged_as_spam.count).to be 2
  end

  it "knows all the spam flags on a users content" do
    u = User.make!
    u.flags_on_spam_content.count.should == 0
    3.times do
      obs = Observation.make!(user: u)
      Flag.make!(flaggable: obs, flag: Flag::SPAM)
      Flag.make!(flaggable: obs, flag: "something else")
    end
    u.flags_on_spam_content.count.should == 3
  end

end
