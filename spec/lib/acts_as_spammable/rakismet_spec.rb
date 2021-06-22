require "spec_helper"

describe Rakismet, "ActiveRecord" do

  it "knows the spammable models" do
    expect(Rakismet.spammable_models).to eq [ Observation, Post, Comment,
      Identification, Message, List, Project, Guide, GuideSection,
      User, CheckList ]
  end

  it "knows good fake_environment_variables" do
    expect(Rakismet.fake_environment_variables).to eq({
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_USER_AGENT" =>
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36"
    })
  end

  it "should disable API calls" do
    expect(Rakismet).to receive(:akismet_call).at_least(:once).and_return("true")
    @spam_user = User.make!(name: "viagra-test-123")
    # with Rakismet endabled, spam? gets called and a flag is made
    Rakismet.disabled = false
    g = make_spammy_guide
    expect(g.flagged_as_spam?).to be true
    # with Rakismet disabled, spam? won't get called and thus no flag is made
    Rakismet.disabled = true
    g = make_spammy_guide
    expect(g.flagged_as_spam?).to be false
  end

end

def make_spammy_guide
  Guide.make!(description: "anything")
end
