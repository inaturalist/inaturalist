# frozen_string_literal: true

class UserDeathsController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required
  before_action :load_record, only: [:edit, :update, :destroy]

  layout "bootstrap-container"

  def new
    @user_death = UserDeath.new( user_id: params[:user_id] )
  end

  def create
    @user_death = UserDeath.new( user_death_params )
    @user_death.updater = current_user
    if @user_death.save
      respond_to do | format |
        format.html do
          flash[:notice] = "User death created"
          redirect_to @user_death.user
        end
      end
    else
      respond_to do | format |
        format.html do
          flash[:error] = @user_death.errors.full_messages.to_sentence
          render :new
        end
      end
    end
  end

  def edit; end

  def update
    @user_death.updater = current_user
    if @user_death.save
      respond_to do | format |
        format.html do
          flash[:notice] = "User death updated"
          redirect_to @user_death.user
        end
      end
    else
      respond_to do | format |
        format.html do
          flash[:error] = @user_death.errors.full_messages.to_sentence
          render :edit
        end
      end
    end
  end

  def destroy
    @user_death.destroy
    respond_to do | format |
      format.html do
        flash[:notice] = "User death created"
        redirect_to @user_death.user
      end
    end
  end

  private

  def user_death_params
    params.require( :user_death ).permit(
      :obituary_url,
      :tributes_url,
      :died_on,
      :user_id
    )
  end
end
