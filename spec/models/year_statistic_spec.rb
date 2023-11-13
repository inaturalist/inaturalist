# frozen_string_literal: true

require "spec_helper"

describe YearStatistic do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :year_statistic_localized_shareable_images ) }

  describe ".publications" do
    it "should match the YearStatistic.publications method" do
      VCR.use_cassette( "search_gbif_literature" ) do
        publications = YearStatistic.publications( 2022 )

        expect( publications[:count] ).to be_kind_of( Numeric )
        expect( publications[:url] ).to start_with( "https://api.gbif.org/v1/literature/search" )
        expect( publications[:results] ).to be_an_instance_of( Array )
        expect(
          publications[:results][0]["_gbifDOIs"].any? do | doi |
            doi.start_with?( "gbifDOI:" )
          end
        ).to be false
      end
    end
  end
end
