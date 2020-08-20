class UserMutesController < ApplicationController
  before_action :doorkeeper_authorize!, if: ->{ authenticate_with_oauth? }
  before_filter :authenticate_user!, unless: ->{ authenticated_with_oauth? }

  def create
    @user_mute = UserMute.new( permit_params )
    @user_mute.user = current_user
    respond_to do |format|
      if @user_mute.save
        format.html do
          flash[:notice] = I18n.t( :user_muted )
          redirect_to( generic_edit_user_path )
        end
        format.json do
          render json: @user_mute
        end
      else
        format.html do
          flash[:error] = @user_mute.errors.full_messages.to_sentence
          redirect_to( generic_edit_user_path )
        end
        format.json do
          render status: :unprocessable_entity, json: @user_mute.errors
        end
      end
    end
  end

  def destroy
    @user_mute = current_user.user_mutes.where( id: params[:id] ).first
    if @user_mute && @user_mute.user == current_user
      @user_mute.destroy
    end
    respond_to do |format|
      format.html do
        flash[:notice] = I18n.t( :mute_removed )
        redirect_to( generic_edit_user_path )
      end
      format.json { head :no_content }
    end
  end

  private

  def permit_params
    return if params[:user_mute].blank?
    params.require(:user_mute).permit(:muted_user_id)
  end
end
