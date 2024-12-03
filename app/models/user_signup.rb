# frozen_string_literal: true

class UserSignup < ApplicationRecord
  belongs_to :user

  before_validation :set_vpn_status
  before_validation :set_root_user_id_by_ip
  before_validation :set_root_user_id_by_browser_id

  private

  def set_vpn_status
    vpn_checker = VPNChecker.new
    self.vpn = vpn_checker.ip_in_vpn_range?( ip )
  end

  def set_root_user_id_by_ip
    first_signup = UserSignup.where( ip: ip ).
      where( "created_at >= ?", 5.days.ago ).
      order( :created_at ).
      first
    self.root_user_id_by_ip = first_signup&.user_id
  end

  def set_root_user_id_by_browser_id
    return if browser_id.blank?

    first_signup = UserSignup.where( browser_id: browser_id ).
      order( :created_at ).
      first
    self.root_user_id_by_browser_id = first_signup&.user_id
  end
end
