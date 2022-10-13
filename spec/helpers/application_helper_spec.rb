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
  end

  describe "formatted_user_text" do
    let( :html_list ) do
      <<~HTML
        <ul>
          <li>foo</li>
        </ul>
      HTML
    end
    let( :html_table ) do
      <<~HTML
        <table>
          <tr>
            <td>foo</td>
          </tr>
        </table>
      HTML
    end
    let( :markdown_list ) do
      <<~MARKDOWN
        This is a list
        1. First item
          1. First sub-item
          2. Second sub-item
        2. Second item
      MARKDOWN
    end
    it "should not add unnecessary breaks around list items" do
      parsed = formatted_user_text( html_list )
      expect( parsed ).to include "<ul"
      expect( parsed ).not_to include "<br"
    end

    it "should not add unnecessary breaks around list items in markdown" do
      parsed = formatted_user_text( markdown_list )
      expect( parsed ).to include "<ol"
      expect( parsed ).not_to include "<br"
    end

    it "should not add unnecessary breaks around a table when tables are allowd" do
      parsed = formatted_user_text(
        html_table,
        scrubber: PostScrubber.new( tags: Post::ALLOWED_TAGS, attributes: Post::ALLOWED_ATTRIBUTES )
      )
      expect( parsed ).to include "<table"
      expect( parsed ).not_to be_blank
      expect( parsed ).not_to include "<br"
    end

    it "should not have li's outside of ol's" do
      parsed = formatted_user_text( markdown_list )
      frag = Nokogiri::HTML::DocumentFragment.parse( parsed )
      expect( frag.xpath( "/li" ) ).to be_blank
    end

    it "should apply paragraphs to lines between lists" do
      para_between_lists = <<~MARKDOWN
        List 1
        * item 1

        in between 1

        in between 2

        List 2
        * item 2
      MARKDOWN
      parsed = formatted_user_text( para_between_lists )
      expect( parsed ).to include "<p>in between 1</p>"
    end
  end
end
