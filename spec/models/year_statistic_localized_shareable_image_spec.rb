# frozen_string_literal: true

require "spec_helper"

describe YearStatisticLocalizedShareableImage do
  it { is_expected.to belong_to :year_statistic }
  it { is_expected.to validate_presence_of :year_statistic }
  it { is_expected.to validate_presence_of :locale }

  let( :count ) { 1_000_000 }
  let( :preferred_key ) { "x_observations_caps_html" }
  let( :fallback_key ) { "x_observations_html" }

  describe "stat_count_labels" do
    it "returns a localized count and label" do
      count_text, label_text = YearStatisticLocalizedShareableImage.new( locale: "en" ).stat_count_labels(
        preferred_key,
        fallback_key,
        count
      )
      expect( count_text ).to eq ApplicationController.helpers.number_with_delimiter( count, locale: "en" )
      expect( label_text ).to eq(
        I18n.t( preferred_key, locale: "en", count: count ).sub( /<.*>/, "" ).strip
      )

      count_text, label_text = YearStatisticLocalizedShareableImage.new( locale: "et" ).stat_count_labels(
        preferred_key,
        fallback_key,
        count
      )
      expect( count_text ).to eq ApplicationController.helpers.number_with_delimiter( count, locale: "et" )
      expect( label_text ).to eq(
        I18n.t( preferred_key, locale: "et", count: count ).sub( /<.*>/, "" ).strip
      )
    end

    it "uses the fallback translation key if the primary is missing" do
      expect( I18n ).to receive( :has_t? ).
        with( preferred_key, locale: "en" ).and_return( false )
      expect( I18n ).to receive( :has_t? ).
        with( fallback_key, locale: "en" ).and_return( true )
      expect( I18n ).to receive( :t ).with(
        fallback_key,
        count: count,
        locale: "en",
        skip_interpolation: true
      ).at_least( :once ).and_call_original
      YearStatisticLocalizedShareableImage.new( locale: "en" ).stat_count_labels(
        preferred_key,
        fallback_key,
        count
      )
    end
  end
end
