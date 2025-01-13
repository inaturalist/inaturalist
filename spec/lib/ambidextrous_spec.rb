# frozen_string_literal: true

require "spec_helper"

describe Ambidextrous do
  let( :test_class ) { Class.new { include Ambidextrous } }
  let( :instance ) { test_class.new }

  describe "check user agent" do
    let( :android_user_agents ) do
      [
        "iNaturalist/1.36.2 (Build 622; Android 4.14.186+ R.f4e9ea_ba1; SDK 31; RMX3191 RMX3191 RMX3191RU; OS Version 12)",
        "iNaturalist/1.36.2 (Build 622; Android 4.14.180-perf-g7979cf1aff8e V12.5.5.0.RJUEUXM; SDK 30; vayu M2102J20SG vayu_eea; OS Version 11)",
        "iNaturalist/1.36.2 (Build 622; Android 4.19.113-27223811 G781WVLSHHXJ1; SDK 33; r8q SM-G781W r8qcsx; OS Version 13)",
        "iNaturalist/1.36.2 (Build 622; Android 6.1.75-android14-11-29150220-abF956BXXS2AXKC F956BXXS2AXKC; SDK 34; q6q SM-F956B q6qxxx; OS Version 14)",
        "iNaturalist/1.35.5 (Build 619; Android 4.14.186-g7c18952d3c68 V12.5.8.0.RGGMIXM; SDK 30; begonia Redmi Note 8 Pro begonia; OS Version 11)",
        "iNaturalist/1.12.4 (Build 363; Android 4.14.98-perf+ V11.0.12.0.PCOMIXM; SDK 28; ginkgo Redmi Note 8 ginkgo)",
        "iNaturalist/1.28.10 (Build 563; Android 4.9.112-perf+ cb359; SDK 28; surfna moto e6 surfna_t; OS Version 9)"
      ]
    end

    let( :ios_user_agents ) do
      [
        "iNaturalist/720 CFNetwork/1568.200.51 Darwin/24.1.0",
        "iNaturalist/720 CFNetwork/1568.300.101 Darwin/24.2.0",
        "iNaturalist/3.3.5 (iPhone; iOS 18.1.1; Scale/3.00)",
        "iNaturalist/720 CFNetwork/1485 Darwin/23.1.0",
        "iNaturalist/716 CFNetwork/1498.700.2 Darwin/23.6.0"
      ]
    end

    let( :react_user_agents ) do
      [
        "iNaturalistRN/0.55.3 (Build 130; iOS 18.2; iPhone15,3; Handset; Apple)",
        "iNaturalistRN/0.55.3 (Build 130; iOS 18.1.1; iPhone14,7; Handset; Apple)",
        "iNaturalistReactNative/130 CFNetwork/1568.200.51 Darwin/24.1.0",
        "iNaturalistReactNative/132 CFNetwork/1568.200.51 Darwin/24.1.0",
        "iNaturalistRN/0.57.0 (Build 132; iOS 18.1.1; iPhone16,2; Handset; Apple)"
      ]
    end

    let( :other_user_agents ) do
      [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1.1 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:133.0) Gecko/20100101 Firefox/133.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/116.0.1938.76 Safari/537.36",
        "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Amazonbot/0.1; +https://developer.amazon.com/support/amazonbot) Chrome/119.0.6045.214 Safari/537.36",
        "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.139 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "libcurl/8.3.0 r-curl/5.2.1 httr/1.4.7",
        "ChatGPT/1.2024.347 (iOS 17.7; iPhone13,1; build 12404571507)",
        "Seek/2.16.4 Handset (Build 371) Android/15",
        "Zapier"
      ]
    end

    it "when Android" do
      android_user_agents.each do | user_agent |
        request_double = double( "request" )
        allow( request_double ).to receive( :user_agent ).and_return( user_agent )
        allow( request_double ).to receive( :headers ).and_return( { "X-Via" => "other" } )
        allow( instance ).to receive( :request ).and_return( request_double )
        expect( instance.send( :is_android_app? ) ).to be true
        expect( instance.send( :is_iphone_app? ) ).to be false
        expect( instance.send( :is_inatrn_app? ) ).to be false
      end
    end

    it "when iOS" do
      ios_user_agents.each do | user_agent |
        request_double = double( "request" )
        allow( request_double ).to receive( :user_agent ).and_return( user_agent )
        allow( request_double ).to receive( :headers ).and_return( { "X-Via" => "other" } )
        allow( instance ).to receive( :request ).and_return( request_double )
        expect( instance.send( :is_android_app? ) ).to be false
        expect( instance.send( :is_iphone_app? ) ).to be true
        expect( instance.send( :is_inatrn_app? ) ).to be false
      end
    end

    it "when React Native" do
      react_user_agents.each do | user_agent |
        request_double = double( "request" )
        allow( request_double ).to receive( :user_agent ).and_return( user_agent )
        allow( request_double ).to receive( :headers ).and_return( { "X-Via" => "other" } )
        allow( instance ).to receive( :request ).and_return( request_double )
        expect( instance.send( :is_android_app? ) ).to be false
        expect( instance.send( :is_iphone_app? ) ).to be false
        expect( instance.send( :is_inatrn_app? ) ).to be true
      end
    end

    it "when other" do
      other_user_agents.each do | user_agent |
        request_double = double( "request" )
        allow( request_double ).to receive( :user_agent ).and_return( user_agent )
        allow( request_double ).to receive( :headers ).and_return( { "X-Via" => "other" } )
        allow( instance ).to receive( :request ).and_return( request_double )
        expect( instance.send( :is_android_app? ) ).to be false
        expect( instance.send( :is_iphone_app? ) ).to be false
        expect( instance.send( :is_inatrn_app? ) ).to be false
      end
    end
  end
end
