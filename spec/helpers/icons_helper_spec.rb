# frozen_string_literal: true

require "spec_helper"

describe IconsHelper, type: :helper do
  describe "icon_svg" do
    it "inlines the named icon as decorative markup" do
      svg = Nokogiri::HTML.fragment( helper.icon_svg( "arrow-left" ) ).at_css( "svg" )
      expect( svg["aria-hidden"] ).to eq "true"
      expect( svg["stroke"] ).to eq "currentColor"
    end

    it "is html safe" do
      expect( helper.icon_svg( "chevron-down" ) ).to be_html_safe
    end

    it "reads each icon from disk once" do
      helper.icon_svg( "arrow-right" )
      expect( File ).not_to receive( :read )
      helper.icon_svg( "arrow-right" )
    end

    it "raises for an unknown icon" do
      expect { helper.icon_svg( "nope" ) }.to raise_error( Errno::ENOENT )
    end
  end
end
