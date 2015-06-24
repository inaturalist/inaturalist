require "spec_helper"

describe "Extensions" do
  describe "force_utf8" do
    before do
      @str = "\xC2\xA9"
      @str.force_encoding("ISO-8859-1")
    end

    describe Array do
      it "converts to utf8" do
        arr = [ @str ]
        expect( arr.first.encoding.to_s ).to eq( "ISO-8859-1" )
        arr = arr.force_utf8
        expect( arr.first.encoding.to_s ).to eq( "UTF-8" )
      end

      it "converts complicated arrays to utf8" do
        arr = [ { arr: [ { str: @str } ] } ]
        expect( arr.first[:arr].first[:str].encoding.to_s ).to eq( "ISO-8859-1" )
        arr = arr.force_utf8
        expect( arr.first[:arr].first[:str].encoding.to_s ).to eq( "UTF-8" )
      end

      it "converts NaN to nil" do
        arr = [ 0.0/0 ]
        expect( arr.first.nan? ).to be true
        expect( arr.first).to_not be nil
        arr = arr.force_utf8
        expect( arr.first).to be nil
      end
    end

    describe Hash do
      it "converts to utf8" do
        h = { str: @str }
        expect( h[:str].encoding.to_s ).to eq( "ISO-8859-1" )
        h = h.force_utf8
        expect( h[:str].encoding.to_s ).to eq( "UTF-8" )
      end

      it "converts complicated hashes to utf8" do
        h = { h: [ { arr: [ @str ] } ] }
        expect( h[:h].first[:arr].first.encoding.to_s ).to eq( "ISO-8859-1" )
        h = h.force_utf8
        expect( h[:h].first[:arr].first.encoding.to_s ).to eq( "UTF-8" )
      end

      it "converts NaN to nil" do
        h = { value: 0.0/0 }
        expect( h[:value].nan? ).to be true
        expect( h[:value] ).to_not be nil
        h = h.force_utf8
        expect( h[:value] ).to be nil
      end
    end
  end
end
