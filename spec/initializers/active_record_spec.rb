require "spec_helper"

describe "ActiveRecord::Base" do
  describe "split_date" do
    it "splits dates" do
      split_date = Observation.split_date( Time.now )
      expect( split_date[:day] ).to eq Time.now.day
      expect( split_date[:month] ).to eq Time.now.month
      expect( split_date[:year] ).to eq Time.now.year
    end

    it "can split date based on utc dates" do
      time = Time.parse("2014-12-31 20:00:00 -0800")
      original = Observation.split_date( time )
      expect( original[:day] ).to eq 31
      expect( original[:month] ).to eq 12
      expect( original[:year] ).to eq 2014
      utc = Observation.split_date( time, utc: true )
      expect( utc[:day] ).to eq 1
      expect( utc[:month] ).to eq 1
      expect( utc[:year] ).to eq 2015
    end

    it "apply utc to 'today'" do
      today = Time.now
      original = Observation.split_date( "today" )
      expect( original[:day] ).to eq today.day
      utc = Observation.split_date( "today", utc: true )
      expect( utc[:day] ).to eq today.utc.day
    end
  end
end
