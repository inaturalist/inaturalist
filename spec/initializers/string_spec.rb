require "spec_helper"

describe String do
  it "knows which strings are yesish" do
    expect( "1".yesish? ).to be true
    expect( "yes".yesish? ).to be true
    expect( "y".yesish? ).to be true
    expect( "true".yesish? ).to be true
    expect( "t".yesish? ).to be true

    expect( "2".yesish? ).to be false
    expect( "ye".yesish? ).to be false
    expect( "tr".yesish? ).to be false
    expect( "tru".yesish? ).to be false
  end

  it "knows which strings are noish" do
    expect( "0".noish? ).to be true
    expect( "no".noish? ).to be true
    expect( "n".noish? ).to be true
    expect( "false".noish? ).to be true
    expect( "f".noish? ).to be true

    expect( "2".noish? ).to be false
    expect( "not".noish? ).to be false
    expect( "fa".noish? ).to be false
    expect( "fals".noish? ).to be false
  end
end

describe NilClass do
  it "is not yesish or noish" do
    expect( nil.yesish? ).to be false
    expect( nil.noish? ).to be false
  end
end

describe TrueClass do
  it "is yesish" do
    expect( true.yesish? ).to be true
    expect( true.noish? ).to be false
  end
end

describe FalseClass do
  it "is noish" do
    expect( false.yesish? ).to be false
    expect( false.noish? ).to be true
  end
end

describe Integer do
  it "knows which numbers are yesish" do
    expect( 0.yesish? ).to be false
    expect( 1.yesish? ).to be true
    expect( 2.yesish? ).to be false
  end

  it "knows which numbers are noish" do
    expect( 0.noish? ).to be true
    expect( 1.noish? ).to be false
    expect( 2.noish? ).to be false
  end
end
