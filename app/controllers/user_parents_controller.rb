# frozen_string_literal: true

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
    respond_to do | format |
      format.html
    end
  end

  def create
    @user_parent = UserParent.new( params[:user_parent] )
    @user_parent.parent_user = current_user
    session[:user_parent_name] = @user_parent.name
    session[:user_parent_email] = @user_parent.email
    respond_to do | format |
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
      if ( @user_parent = UserParent.where( id: params[:id], parent_user_id: current_user ).first )
        @user_parent_name = @user_parent.name
        @user_parent_email = @user_parent.email
      end
    else
      @user_parent = UserParent.find_by_id( params[:id] )
    end
    unless @user_parent
      respond_to do | format |
        format.html { render_404 }
      end
      return
    end

    new_params = redirect_params
    redirect_to confirm_user_parent_path( @user_parent, new_params ) if new_params

    # Otherwise load it from the session so other people can't see the data in UserParent record
    @user_parent_name ||= session[:user_parent_name] || ""
    @user_parent_email ||= session[:user_parent_email] || ""
    if @user_parent_name.blank? && @user_parent_email.blank?
      respond_to do | format |
        format.html { redirect_back_or_default new_user_parent_path }
      end
      return
    end
    respond_to do | format |
      format.html
    end
  end

  private

  def set_instance_variables
    @footless = true
    @no_footer_gap = true
    @responsive = true
  end

  def redirect_params
    # if there is a redirect param then an attempt has already been made to
    # include utm params on redirect, so do not attempt to redirect again
    return nil if params[:redirect]

    params_for_redirect = {
      redirect: true
    }
    if @user_parent && !@user_parent.donor?
      # in order for FundraiseUp to populate the name and email fields with what we specify here,
      # which is helpful to ensure the same email address is used to connect the donation with the
      # account, the elementId parameter must be set to the value of the donation form element
      params_for_redirect.merge!( {
        elementId: "XDBENMYL",
        utm_content: "user_parent",
        email: @user_parent_email,
        firstName: @user_parent_name.split.first,
        lastName: @user_parent_name.split.last,
        utm_source: @site.name,
        utm_medium: "web"
      } )
    end
    params_for_redirect.merge(
      request.query_parameters.reject {| k, _v | k.to_s == "inat_site_id" }
    )
  end
end
