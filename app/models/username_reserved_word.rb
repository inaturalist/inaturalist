# frozen_string_literal: true

class UsernameReservedWord < ApplicationRecord
  validates_presence_of :word
  validates_uniqueness_of :word

  after_commit :clear_cache, on: [:create, :update, :destroy]

  def clear_cache
    UsernameReservedWord.clear_cache
  end

  def self.clear_cache
    Rails.cache.delete( "username_reserved_words" )
  end

  def self.all_cached
    Rails.cache.fetch( "username_reserved_words" ) do
      UsernameReservedWord.all.to_a
    end
  end
end
