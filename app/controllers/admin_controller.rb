require_relative "../models/delayed_job" if Rails.env.development?
#
# A collection of tools useful for administrators.
#
class AdminController < ApplicationController

  before_filter :authenticate_user!
  before_filter :admin_required
  before_filter :return_here, :only => [:stats, :index, :user_content]

  layout "application"

  def index
    render layout: "admin"
  end

  def user_content
    return unless load_user_content_info
    @records = @display_user.send(@reflection_name).page(params[:page]) rescue []
  end

  def update_user
    unless u = User.find_by_id(params[:id])
      flash[:error] = "User doesn't exist"
      redirect_back_or_default(curate_users_path)
    end
    u.update_attributes(params[:user]) if params[:user]
    if params[:icon_delete]
      u.icon = nil
      u.save
    end
    flash[:notice] = "Updated attributes for #{u.login}"
    redirect_back_or_default(curate_users_path(:user_id => u.id))
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

  private
  def load_user_content_info
    user_id = params[:id] || params[:user_id]
    @display_user = User.find_by_id(user_id)
    @display_user ||= User.find_by_login(user_id)
    @display_user ||= User.find_by_email(user_id)
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
