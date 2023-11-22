# frozen_string_literal: true

require "spec_helper"

describe I18n do
  describe "plurals" do
    it "uses the same form for Maori regardless of count" do
      zero_form = I18n.t( :x_observers_html, count: 0, locale: :mi )
      expect( zero_form ).to_not be_nil
      [1, 2, 3, 11, 100].each do | count |
        expect(
          I18n.t( :x_observers_html, count: count, locale: :mi )
        ).to eq zero_form.sub( "0", count.to_s )
      end
    end
  end
end
