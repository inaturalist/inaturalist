# frozen_string_literal: true

require "spec_helper"

describe YearStatistic do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :site }
  it { is_expected.to have_many( :year_statistic_localized_shareable_images ) }

  describe ".publications" do
    it "should match the YearStatistic.publications method" do
      publications = YearStatistic.publications( 2022 )
      old_publications = YearStatistic.publications_old( 2022 )

      publications[:results].each.with_index do | result, i |
        expect( result.except( "_gbifDOIs", "title" ) ).to eq(
          old_publications[:results][i].except( "_gbifDOIs", "title" )
        )
        expect( result["_gbifDOIs"] ).to eq(
          old_publications[:results][i]["_gbifDOIs"].map {| doi | doi.delete_prefix( "doi:" ) }
        )
      end

      expect( publications[:count] ).to eq( old_publications[:count] )

      expect( publications[:url] ).not_to eq( old_publications[:url] )
    end
  end
end
