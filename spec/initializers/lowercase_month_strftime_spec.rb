# frozen_string_literal: true

require "spec_helper"

[Date, Time, DateTime].each do | klass |
  describe klass, "strftime" do
    let( :date ) { klass.parse( "2020-01-10" ) }

    it "should replace %=B with a lowercase date" do
      expect( date.strftime( "%-d. %=B %Y" ) ).to eq "10. january 2020"
      expect( date.strftime( "%-d. %=B %Y" ) ).not_to include "January"
    end

    it "should replace %=b with a lowercase date" do
      expect( date.strftime( "%-d. %=b %Y" ) ).to eq "10. jan 2020"
      expect( date.strftime( "%-d. %=b %Y" ) ).not_to include "Jan"
    end
  end
end
