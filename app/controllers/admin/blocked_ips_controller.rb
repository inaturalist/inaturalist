#frozen_string_literal: true

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
      blocked_ip = BlockedIp.find_or_initialize_by( ip: params[:ip] )

      unless blocked_ip.valid?
        flash[:notice] = "Failed to block IP `#{ip}`: #{blocked_ip.errors.full_messages.to_sentence}"
        return redirect_back_or_default( action: "index" )
      end

      blocked_ip.update( user: current_user )
      Rails.cache.delete( "blocked_ips" )

      redirect_to admin_blocked_ips_path( q_ip: params[:q_ip], q_blocked_by: params[:q_blocked_by] )
    end

    def unblock
      blocked_ip = BlockedIp.find_by( ip: params[:ip] )
      blocked_ip&.destroy

      Rails.cache.delete( "blocked_ips" )

      redirect_to admin_blocked_ips_path( q_ip: params[:q_ip], q_blocked_by: params[:q_blocked_by] )
    end
  end
end
