# encoding: UTF-8
require "spec_helper"

describe String do
  describe "mentioned_users" do
    it "finds mentioned users that exist" do
      quick = User.make!(login: "quick")
      fox = User.make!(login: "fox")
      expect("The @quick, @brown @fox @fox!".mentioned_users).to include(quick, fox)
    end

    it "should not find users that are a part of email addresses" do
      user = User.make!(login: 'inaturalist')
      expect( "Email me at foo@inaturalist.org".mentioned_users ).not_to include user
    end

    it "should find users mentioned at the start" do
      quick = User.make!(login: "quick")
      expect("@quick, what do you think of this?".mentioned_users).to include quick
    end

    it "should find users mentioned at the start of a tag" do
      quick = User.make!(login: "quick")
      expect("<p>@quick, what do you think of this?</p>".mentioned_users).to include quick
    end
  end

  describe "context_of_pattern" do
    it "returns nothing of the pattern isn't found" do
      expect(" ".context_of_pattern("missing")).to eq nil
    end

    it "returns a number of characters around a pattern" do
      str = ("a" * 100) + " pattern " + ("b" * 100)
      expect(str.context_of_pattern("pattern", 15)).to eq(
        "..." + ("a" * 14) + " pattern " + ("b" * 14) + "...")
    end
  end
end
