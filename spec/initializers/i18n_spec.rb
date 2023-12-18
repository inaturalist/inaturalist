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

  describe "normalize_locale" do
    it "should remove calendar params" do
      expect( normalize_locale( "zh-Hans-JP@calendar=japanese" ) ).to eq :"zh-CN"
    end

    it "should upcase the region" do
      expect( normalize_locale( "es-mx" ) ).to eq :"es-MX "
    end

    it "should map zh-Hans to zh-CN" do
      expect( normalize_locale( "zh-Hans" ) ).to eq :"zh-CN"
    end

    it "should map zh-Hant to zh-TW" do
      expect( normalize_locale( "zh-Hant" ) ).to eq :"zh-TW"
    end

    it "should map zh-Hant-HK to zh-HK" do
      expect( normalize_locale( "zh-Hant-HK" ) ).to eq :"zh-HK"
    end

    it "should map zh-Hans-HK to zh-CN" do
      expect( normalize_locale( "zh-Hans-HK" ) ).to eq :"zh-CN"
    end

    it "should map an unsupported region to the corresponding regionless language code" do
      expect( normalize_locale( "cs-CZ" ) ).to eq :cs
    end

    it "should return the default for an unsupported locale" do
      expect( normalize_locale( "foo" ) ).to eq I18n.default_locale
    end
  end
end
