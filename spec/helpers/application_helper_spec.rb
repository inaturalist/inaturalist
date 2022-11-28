# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe ApplicationHelper do
  describe "hyperlink_mentions" do
    it "links known user mentions in text" do
      User.make!( login: "testmention" )
      str = "Hello @testmention!"
      expect( hyperlink_mentions( str ) ).to eq(
        "Hello <a href=\"http://test.host/people/testmention\">@testmention</a>!"
      )
    end

    it "does not link unknown logins" do
      str = "Hello @testmention!"
      expect( hyperlink_mentions( str ) ).to eq str
    end

    it "links mentions at the start and end of strings" do
      User.make!( login: "alpha" )
      User.make!( login: "beta" )
      str = "@alpha, @beta"
      expect( hyperlink_mentions( str ) ).to eq(
        "<a href=\"http://test.host/people/alpha\">@alpha</a>, " \
          "<a href=\"http://test.host/people/beta\">@beta</a>"
      )
    end

    it "properly links logins that are substrings of each other" do
      User.make!( login: "alpha" )
      User.make!( login: "alphabeta" )
      User.make!( login: "alphabetagamma" )
      str = "Hello @alpha, @alphabeta, @alphabetagamma"
      expect( hyperlink_mentions( str ) ).to eq(
        "Hello <a href=\"http://test.host/people/alpha\">@alpha</a>, " \
          "<a href=\"http://test.host/people/alphabeta\">@alphabeta</a>, " \
          "<a href=\"http://test.host/people/alphabetagamma\">@alphabetagamma</a>"
      )
    end

    it "ignores links that look like mentions" do
      user = create :user
      txt = <<~TXT
        Hey, it's <a rel="me" href="https://foo.bar/@#{user.login}">me</a>
      TXT
      expect( hyperlink_mentions( txt ) ).to eq txt
    end
  end
end
