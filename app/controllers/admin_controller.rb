# frozen_string_literal: true

#
# A collection of tools useful for administrators.
#
class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required
  before_action :return_here, only: [:stats, :index, :user_content, :user_detail]

  prepend_around_action :enable_replica, only: [:queries]

  layout "application"

  def index
    render layout: "admin"
  end

  def users
    @users = User.paginate( page: params[:page] ).order( id: :desc )
    @comment_counts_by_user_id = Comment.where( user_id: @users ).group( :user_id ).count
    @q = params[:q]
    @users = @users.where(
      "login ILIKE ? OR name ILIKE ? OR email ILIKE ? OR last_ip LIKE ?", "%#{@q}%", "%#{@q}%", "%#{@q}%", "%#{@q}%"
    )
    respond_to do | format |
      format.html { render layout: "admin" }
    end
  end

  def user_detail
    @display_user = User.find_by_id( params[:id].to_i )
    @display_user ||= User.find_by_login( params[:id] )
    @display_user ||= User.find_by_email( params[:id] ) unless params[:id].blank?
    if @display_user
      @observations = Observation.page_of_results( user_id: @display_user.id )
      geoip_response = INatAPIService.geoip_lookup( { ip: @display_user.last_ip } )
      if geoip_response&.results && geoip_response.results.country
        @geoip_location = [
          geoip_response.results.city,
          geoip_response.results.region,
          geoip_response.results.country
        ].join( ", " )
        if geoip_response.results.ll
          @geoip_latitude, @geoip_longitude = geoip_response.results.ll
        end
      end
      @email_suppressions = [
        @display_user.email_suppressions.to_a, EmailSuppression.where( email: @display_user.email ).to_a
      ].flatten.compact.uniq
    end

    respond_to do | format |
      format.html do
        unless @display_user
          return redirect_back_or_default( users_admin_path )
        end

        render layout: "admin"
      end
    end
  end

  def deleted_users
    @deleted_users = DeletedUser.order( "id desc" ).page( params[:page] ).per_page( 100 )
    @q = params[:q]
    @deleted_users = @deleted_users.where(
      "login ILIKE ? OR email ILIKE ?", "%#{@q}%", "%#{@q}%"
    )
    respond_to do | format |
      format.html { render layout: "admin" }
    end
  end

  def user_content
    return unless load_user_content_info

    @page = params[:page]
    @order = params[:order]
    @order = "desc" unless %w(asc desc).include?( @order )
    @order_by = params[:order_by]
    @order_by = "created_at" unless %w(created_at updated_at).include?( @order_by )
    @records = begin
      @display_user.send( @reflection_name ).
        order( @order_by => @order ).page( params[:page] || 1 ).limit( 200 )
    rescue StandardError
      []
    end

    render layout: "bootstrap"
  end

  def update_user
    unless ( user = User.find_by_id( params[:id] ) )
      flash[:error] = "User doesn't exist"
      redirect_back_or_default( curate_users_path )
    end
    if params[:icon_delete]
      user.icon = nil
      user.icon_url = nil
    end
    if params[:confirm]
      user.confirm
    elsif params[:reset_confirmation]
      User.where( id: user.id ).update_all(
        confirmation_token: nil,
        confirmation_sent_at: nil,
        confirmed_at: nil
      )
    end
    if params[:user]
      user.update( params[:user] )
    else
      user.save
    end
    if user.valid?
      flash[:notice] = "Updated attributes for #{user.login}"
    else
      flash[:error] = "Failed to update attributes for #{user.login}: #{user.errors.full_messages.to_sentence}"
    end
    redirect_back_or_default( curate_users_path( user_id: user.id ) )
  end

  def grant_user_privilege
    @up = UserPrivilege.new( user_id: params[:user_id], privilege: params[:privilege] )
    unless @up.save
      flash[:error] = "Failed to grant privilege: #{@up.errors.full_messages.to_sentence}"
    end
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def revoke_user_privilege
    @up = UserPrivilege.where( user_id: params[:user_id], privilege: params[:privilege] ).first
    unless @up
      flash[:error] = "User #{params[:user_id]} doesn't have the #{params[:privilege]} privilege"
      return redirect_to user_detail_admin_path( id: params[:user_id] )
    end
    @up.revoke!( revoke_user: current_user, revoke_reason: params[:reason] )
    flash[:notice] = "Revoked #{params[:privilege]} privilege for user #{@up.user.login}"
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def restore_user_privilege
    @up = UserPrivilege.where( user_id: params[:user_id], privilege: params[:privilege] ).first
    unless @up
      flash[:error] = "User #{params[:user_id]} doesn't have the #{params[:privilege]} privilege"
      return redirect_to user_detail_admin_path( id: params[:user_id] )
    end
    unless @up.restore!
      flash[:error] = "Failed to restore privilege: #{@up.errors.full_messages.to_sentence}"
    end
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def reset_user_privilege
    @up = UserPrivilege.where( user_id: params[:user_id], privilege: params[:privilege] ).first
    unless @up
      flash[:error] = "User #{params[:user_id]} doesn't have the #{params[:privilege]} privilege"
      return redirect_to user_detail_admin_path( id: params[:user_id] )
    end
    @up&.destroy
    UserPrivilege.check( params[:user_id], params[:privilege] )
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def destroy_user_content
    return unless load_user_content_info

    @records = @display_user.send( @reflection_name ).
      where( "#{@reflection.table_name}.id IN (?)", params[:ids] || [] )
    @records.each( &:destroy )
    flash[:notice] = "Deleted #{@records.size} #{@type.humanize.downcase}"
    redirect_back_or_default( admin_user_content_path( @display_user.id, @type ) )
  end

  def login_as
    unless ( user = User.find_by_id( params[:id] || [params[:user_id]] ) )
      flash[:error] = "That user doesn't exist"
      redirect_back_or_default( :index )
    end
    sign_out :user
    sign_in user

    flash[:notice] = "Logged in as #{user.login}. Be careful, and remember to log out when you're done."
    redirect_to root_path
  end

  def queries
    replica_pool = ActiveRecord::Base.connection.instance_variable_get( "@replica_pool" )
    if replica_pool
      # if configured to use replica DBs with Makara, fetch queries from all primaries and replicas
      primary_pool = ActiveRecord::Base.connection.instance_variable_get( "@primary_pool" )
      @queries = []
      ( primary_pool.connections + replica_pool.connections ).flatten.each do | connection |
        instance_queries = connection.active_queries.map do | q |
          { db_host: connection.config[:host] }.merge( q )
        end
        @queries += instance_queries
      end
    else
      @queries = ActiveRecord::Base.connection.active_queries.map do | q |
        { db_host: ActiveRecord::Base.connection_db_config.host }.merge( q )
      end
    end
    @queries.delete_if {| q | q["query"] =~ /pg_stat_activity/ }
    render layout: "admin"
  end

  private

  def load_user_content_info
    user_id = params[:id] || params[:user_id]
    @display_user = User.find_by_id( user_id )
    @display_user ||= User.find_by_login( user_id )
    @display_user ||= User.find_by_email( user_id ) unless user_id.blank?
    unless @display_user
      flash[:error] = "User #{user_id} doesn't exist"
      redirect_back_or_default( action: "index" )
      return false
    end

    @type = params[:type] || "observations"
    @reflection_name, @reflection = User.reflections.detect {| k, _r | k.to_s == @type }
    @klass = begin
      Object.const_get( @reflection.class_name )
    rescue StandardError
      nil
    end
    @klass = nil unless @klass < ActiveRecord::Base
    unless @klass
      flash[:error] = "#{params[:type]} doesn't exist"
      redirect_back_or_default( action: "index" )
      return false
    end

    @reflection_names = []
    has_many_reflections = User.reflections.select {| _k, v | v.macro == :has_many }
    has_many_reflections.each do | k, reflection |
      # Avoid those pesky :through relats
      next unless reflection.klass.column_names.include?( reflection.foreign_key )

      @reflection_names << k.to_s
    end
    @reflection_names.uniq!
    true
  end
end
