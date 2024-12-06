# frozen_string_literal: true

class BlockedIp < ApplicationRecord
  belongs_to :user
  validates_uniqueness_of :ip
  validate :ip_format_valid

  private

  def ip_format_valid
    return if IPAddr.new( ip ) rescue nil

    errors.add( :ip, "IP is not a valid IP address" )
  end
end
