# frozen_string_literal: true

require "spec_helper"

describe UsernameReservedWord do
  after( :all ) { UsernameReservedWord.destroy_all }

  it { is_expected.to validate_presence_of :word }
  it { is_expected.to validate_uniqueness_of :word }

  describe "all_cached" do
    it "returns words from a cache" do
      UsernameReservedWord.make!( word: "one" )
      all_words = UsernameReservedWord.all
      expect( all_words.length ).to eq 1
      expect( UsernameReservedWord ).to receive( :all ).and_call_original
      expect( UsernameReservedWord.all_cached ).to eq all_words

      expect( UsernameReservedWord ).not_to receive( :all )
      expect( UsernameReservedWord.all_cached ).to eq all_words
      expect( UsernameReservedWord.all_cached ).to eq all_words
    end
  end

  describe "cache" do
    it "cache is cleared when new words are created" do
      UsernameReservedWord.make!( word: "one" )
      expect( UsernameReservedWord.all.length ).to eq 1
      expect( UsernameReservedWord.all_cached ).to eq UsernameReservedWord.all
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be true

      UsernameReservedWord.make!( word: "two" )
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be false
      expect( UsernameReservedWord.all.length ).to eq 2
      expect( UsernameReservedWord.all_cached ).to eq UsernameReservedWord.all
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be true
    end

    it "cache is cleared when words are updated" do
      UsernameReservedWord.make!( word: "one" )
      expect( UsernameReservedWord.all.length ).to eq 1
      expect( UsernameReservedWord.all_cached ).to eq UsernameReservedWord.all
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be true

      UsernameReservedWord.first.update( word: "newone" )
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be false
      expect( UsernameReservedWord.all.length ).to eq 1
      expect( UsernameReservedWord.all_cached ).to eq UsernameReservedWord.all
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be true
    end

    it "cache is cleared when words are destroyed" do
      UsernameReservedWord.make!( word: "one" )
      UsernameReservedWord.make!( word: "two" )
      expect( UsernameReservedWord.all.length ).to eq 2
      expect( UsernameReservedWord.all_cached ).to eq UsernameReservedWord.all
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be true

      UsernameReservedWord.last.destroy
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be false
      expect( UsernameReservedWord.all.length ).to eq 1
      expect( UsernameReservedWord.all_cached ).to eq UsernameReservedWord.all
      expect( Rails.cache.exist?( "username_reserved_words" ) ).to be true
    end
  end
end
