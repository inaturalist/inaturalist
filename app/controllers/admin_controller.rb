require_relative "../models/delayed_job" if Rails.env.development?
#
# A collection of tools useful for administrators.
#
class AdminController < ApplicationController

  before_filter :authenticate_user!
  before_filter :admin_required
  before_filter :return_here, only: [:stats, :index, :user_content, :user_detail]

  layout "application"

  def index
    render layout: "admin"
  end

  def users
    @users = User.paginate(page: params[:page]).order(id: :desc)
    @comment_counts_by_user_id = Comment.where(user_id: @users).group(:user_id).count
    @q = params[:q]
    @users = @users.where(
      "login ILIKE ? OR name ILIKE ? OR email ILIKE ? OR last_ip LIKE ?", "%#{@q}%", "%#{@q}%", "%#{@q}%", "%#{@q}%"
    )
    respond_to do |format|
      format.html { render layout: "admin" }
    end
  end

  def user_detail
    @display_user = User.find_by_id(params[:id].to_i)
    @display_user ||= User.find_by_login(params[:id])
    @display_user ||= User.find_by_email(params[:id]) unless params[:id].blank?
    @observations = Observation.page_of_results( user_id: @display_user.id ) if @display_user

    respond_to do |format|
      format.html do
        if !@display_user
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
    respond_to do |format|
      format.html { render layout: "admin" }
    end
  end

  def user_content
    return unless load_user_content_info
    @order = params[:order]
    @order = "desc" unless %w(asc desc).include?( @order )
    @order_by = params[:order_by]
    @order_by = "created_at" unless %w(created_at updated_at).include?( @order_by )
    @records = @display_user.send( @reflection_name ).order( "#{@order_by} #{@order}" ) rescue []

    render layout: "bootstrap"
  end

  def update_user
    unless u = User.find_by_id(params[:id])
      flash[:error] = "User doesn't exist"
      redirect_back_or_default(curate_users_path)
    end
    if params[:icon_delete]
      u.icon = nil
      u.icon_url = nil
    end
    if params[:user]
      u.update_attributes( params[:user] )
    else
      u.save
    end
    if u.valid?
      flash[:notice] = "Updated attributes for #{u.login}"
    else
      flash[:error] = "Failed to update attributes for #{u.login}: #{u.errors.full_messages.to_sentence}"
    end
    redirect_back_or_default(curate_users_path( user_id: u.id ) )
  end

  def grant_user_privilege
    @up = UserPrivilege.new( user_id: params[:user_id], privilege: params[:privilege] )
    unless @up.save
      flash[:error] = "Failed to grant privilege: #{@up.errors.full_messages.to_sentence}"
    end
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def revoke_user_privilege
    unless @up = UserPrivilege.where( user_id: params[:user_id], privilege: params[:privilege] ).first
      flash[:error] = "User #{params[:user_id]} doesn't have the #{params[:privilege]} privilege"
      return redirect_to user_detail_admin_path( id: params[:user_id] )
    end
    @up.revoke!( revoke_user: current_user, revoke_reason: params[:reason] )
    flash[:notice] = "Revoked #{params[:privilege]} privilege for user #{@up.user.login}"
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def restore_user_privilege
    unless @up = UserPrivilege.where( user_id: params[:user_id], privilege: params[:privilege] ).first
      flash[:error] = "User #{params[:user_id]} doesn't have the #{params[:privilege]} privilege"
      return redirect_to user_detail_admin_path( id: params[:user_id] )
    end
    unless @up.restore!
      flash[:error] = "Failed to restore privilege: #{@up.errors.full_messages.to_sentence}"
    end
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def reset_user_privilege
    unless @up = UserPrivilege.where( user_id: params[:user_id], privilege: params[:privilege] ).first
      flash[:error] = "User #{params[:user_id]} doesn't have the #{params[:privilege]} privilege"
      return redirect_to user_detail_admin_path( id: params[:user_id] )
    end
    @up.destroy if @up
    UserPrivilege.check( params[:user_id], params[:privilege] )
    redirect_to user_detail_admin_path( id: params[:user_id] )
  end

  def destroy_user_content
    return unless load_user_content_info
    @records = @display_user.send(@reflection_name).
      where("id IN (?)", params[:ids] || [])
    @records.each(&:destroy)
    flash[:notice] = "Deleted #{@records.size} #{@type.humanize.downcase}"
    redirect_back_or_default(admin_user_content_path(@display_user.id, @type))
  end
  
  def login_as
    unless user = User.find_by_id(params[:id] || [params[:user_id]])
      flash[:error] = "That user doesn't exist"
      redirect_back_or_default(:index)
    end
    sign_out :user
    sign_in user
    
    flash[:notice] = "Logged in as #{user.login}. Be careful, and remember to log out when you're done."
    redirect_to root_path
  end

  def queries
    @queries = ActiveRecord::Base.connection.active_queries
    render layout: "admin"
  end

  def stop_query
    if params[:pid] && params[:pid].match( /^\d+$/ )
      kill_postgresql_pid( params[:pid].to_i, params[:state] )
    end
    redirect_to :queries_admin
  end

  private

  def kill_postgresql_pid( pid, state = nil )
    return unless pid && pid.is_a?( Integer )
    if state == "idle in transaction"
      ActiveRecord::Base.connection.execute( "SELECT pg_terminate_backend(#{ pid })" )
    else
      ActiveRecord::Base.connection.execute( "SELECT pg_cancel_backend(#{ pid })" )
    end
  end

  def load_user_content_info
    user_id = params[:id] || params[:user_id]
    @display_user = User.find_by_id(user_id)
    @display_user ||= User.find_by_login(user_id)
    @display_user ||= User.find_by_email(user_id) unless user_id.blank?
    unless @display_user
      flash[:error] = "User #{user_id} doesn't exist"
      redirect_back_or_default(:action => "index")
      return false
    end

    @type = params[:type] || "observations"
    @reflection_name, @reflection = User.reflections.detect{|k,r| k.to_s == @type}
    @klass = Object.const_get(@reflection.class_name) rescue nil
    @klass = nil unless @klass.try(:base_class).try(:superclass) == ActiveRecord::Base
    unless @klass
      flash[:error] = "#{params[:type]} doesn't exist"
      redirect_back_or_default(:action => "index")
      return false
    end

    @reflection_names = []
    has_many_reflections = User.reflections.select{|k,v| v.macro == :has_many}
    has_many_reflections.each do |k, reflection|
      # Avoid those pesky :through relats
      next unless reflection.klass.column_names.include?(reflection.foreign_key)
      @reflection_names << k.to_s
    end
    @reflection_names.uniq!
    true
  end
end
