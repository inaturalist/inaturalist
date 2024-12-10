# frozen_string_literal: true

class BlockedIp < ApplicationRecord
  belongs_to :user
  validates :user, presence: true
  validates_uniqueness_of :ip
  validate :ip_format_valid

  private

  def ip_format_valid
    return if IPAddr.new( ip ) rescue nil

    errors.add( :ip, "must be valid IP address" )
  end
end
