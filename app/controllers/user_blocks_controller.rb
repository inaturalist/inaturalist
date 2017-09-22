class UserBlocksController < ApplicationController
  before_action :doorkeeper_authorize!, if: ->{ authenticate_with_oauth? }
  before_filter :authenticate_user!, unless: ->{ authenticated_with_oauth? }

  def create
    @user_block = UserBlock.new( params[:user_block] )
    @user_block.user = current_user
    respond_to do |format|
      if @user_block.save
        format.html do
          flash[:notice] = I18n.t( :user_blocked )
          redirect_to( generic_edit_user_path )
        end
      else
        format.html do
          flash[:error] = @user_block.errors.full_messages.to_sentence
          redirect_to( generic_edit_user_path )
        end
      end
    end
  end

  def destroy
    @user_block = current_user.user_blocks.where( id: params[:id] ).first
    if @user_block && @user_block.user == current_user
      @user_block.destroy
    end
    respond_to do |format|
      format.html do
        flash[:notice] = I18n.t( :block_removed )
        redirect_to( generic_edit_user_path )
      end
    end
  end
end
