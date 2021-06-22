class UserParentsController < ApplicationController
  layout "registrations"
  before_action :set_instance_variables
  before_action :load_record, only: [:destroy]
  before_action :admin_required, only: [:destroy]

  def index
    redirect_to new_user_parent_path
  end

  def new
    @user_parent = UserParent.new( user: User.new )
    if current_user
      @user_parent.name = current_user.name
      @user_parent.email = current_user.email
    end
    respond_to do |format|
      format.html
    end
  end

  def create
    @user_parent = UserParent.new( params[:user_parent] )
    @user_parent.parent_user = current_user
    session[:user_parent_name] = @user_parent.name
    session[:user_parent_email] = @user_parent.email
    respond_to do |format|
      format.html do
        if @user_parent.save
          redirect_to confirm_user_parent_path( @user_parent )
        else
          render :new
        end
      end
    end
  end

  def destroy
    @user_parent.destroy
    redirect_back_or_default( users_admin_path )
  end

  def confirm
    # If the user is signed in, load the data from the UserParent record if they created it
    if current_user
      if @user_parent = UserParent.where( id: params[:id], parent_user_id: current_user ).first
        @user_parent_name = @user_parent.name
        @user_parent_email = @user_parent.email
      end
    else
      @user_parent = UserParent.find_by_id( params[:id] )
    end
    unless @user_parent
      respond_to do |format|
        format.html { render_404 }
      end
      return
    end
    # Otherwise load it from the session so other people can't see the data in UserParent record
    @user_parent_name ||= session[:user_parent_name] || ""
    @user_parent_email ||= session[:user_parent_email] || ""
    if @user_parent_name.blank? && @user_parent_email.blank?
      respond_to do |format|
        format.html { redirect_back_or_default new_user_parent_path }
      end
      return
    end
    respond_to do |format|
      format.html
    end
  end

  private
  def set_instance_variables
    @footless = true
    @no_footer_gap = true
    @responsive = true
  end
end
