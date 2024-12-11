#frozen_string_literal: true

class Admin
  class BlockedIpsController < ApplicationController
    before_action :authenticate_user!
    before_action :admin_required
    before_action :load_record, only: [:destroy]

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

    def create
      blocked_ip = BlockedIp.find_or_initialize_by( ip: params[:ip] )
      blocked_ip.user = current_user

      unless blocked_ip.valid?
        flash[:notice] = "Failed to block IP `#{params[:ip]}`: #{blocked_ip.errors.full_messages.to_sentence}"
        return redirect_back_or_default( action: "index" )
      end

      blocked_ip.save!
      Rails.cache.delete( "blocked_ips" )

      redirect_to admin_blocked_ips_path( q_ip: params[:q_ip], q_blocked_by: params[:q_blocked_by] )
    end

    def destroy
      @blocked_ip.destroy

      Rails.cache.delete( "blocked_ips" )

      redirect_to admin_blocked_ips_path( q_ip: params[:q_ip], q_blocked_by: params[:q_blocked_by] )
    end

    protected

    def load_record( options = {} )
      super( options.merge( klass: BlockedIp ) )
    end
  end
end
