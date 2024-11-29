#frozen_string_literal: true

require "ipaddr"

class Admin
  class BlockedIpsController < ApplicationController
    before_action :authenticate_user!
    before_action :admin_required

    layout "application"

    def index
      @q_blocked_by = params[:q_blocked_by].try( :strip )
      @q_ip = params[:q_ip].try( :strip )

      @blocked_ips = BlockedIp.joins( :user ).all
      @blocked_ips = @blocked_ips.where( "users.login LIKE ?", "%#{@q_blocked_by}%" ) unless @q_blocked_by.blank?
      @blocked_ips = @blocked_ips.where( "blocked_ips.ip LIKE ?", "%#{@q_ip}%" ) unless @q_ip.blank?
      @blocked_ips = @blocked_ips.select( "blocked_ips.*, users.login as login" )
      respond_to do | format |
        format.html { render layout: "admin" }
      end
    end

    def block
      ip = params[:ip]
      return unless is_ip?( ip )

      blocked_ip = BlockedIp.find_or_initialize_by( ip: ip )
      blocked_ip.update( user: current_user )

      Rails.cache.delete( "blocked_ips" )

      redirect_to admin_blocked_ips_path( q_ip: params[:q_ip], q_blocked_by: params[:q_blocked_by] )
    end

    def unblock
      ip = params[:ip]
      blocked_ip = BlockedIp.find_by( ip: ip )
      blocked_ip&.destroy

      Rails.cache.delete( "blocked_ips" )

      redirect_to admin_blocked_ips_path( q_ip: params[:q_ip], q_blocked_by: params[:q_blocked_by] )
    end

    def is_ip?( ip )
      !!IPAddr.new( ip ) rescue false
    end
  end
end
