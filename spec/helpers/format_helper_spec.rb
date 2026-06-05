# frozen_string_literal: true

require "spec_helper"

describe FormatHelper do
  let( :now ) { Time.new( 2026, 1, 1, 12, 0, 0 ) }

  before do
    allow( Time ).to receive( :now ).and_return( now )
  end

  describe "time_until_in_words" do
    it "returns seconds for times less than a minute away" do
      expect( time_until_in_words( now + 30.seconds ) ).to eq "30 seconds"
    end

    it "returns minutes for times less than an hour away" do
      expect( time_until_in_words( now + 15.minutes ) ).to eq "15 minutes"
    end

    it "returns hours for times less than a day away" do
      expect( time_until_in_words( now + 5.hours ) ).to eq "5 hours"
    end

    it "returns days for times less than a month away" do
      expect( time_until_in_words( now + 10.days ) ).to eq "10 days"
    end

    it "returns months for times less than a year away" do
      expect( time_until_in_words( now + 6.months ) ).to eq "6 months"
    end

    it "returns years for times more than a year away" do
      expect( time_until_in_words( now + 2.years ) ).to eq "2 years"
    end

    it "handles times in the past" do
      expect( time_until_in_words( now - 5.hours ) ).to eq "5 hours"
    end

    it "respects locale for internationalized output" do
      I18n.with_locale( :es ) do
        expect( time_until_in_words( now + 10.days ) ).to eq "10 días"
      end
    end
  end
end
