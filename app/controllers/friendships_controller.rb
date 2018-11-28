class FriendshipsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_record, only: [:update]
  before_filter :require_owner, only: [:update]

  layout "bootstrap"

  def index
    @friendships = current_user.friendships.page( params[:page] )
    respond_to do |format|
      format.html
    end
  end

  def update
    render_404 unless @friendship = Friendship.find_by_id( params[:id] )
    @friendship.update_attributes( approved_params )
    respond_to do |format|
      format.html { redirect_back_or_default( person_path( current_user ) ) }
      format.json { render json: { friendship: @friendship } }
    end
  end

  protected
  
  def approved_params
    params.require(:friendship).permit(
      :following,
      :trust
    )
  end
end
