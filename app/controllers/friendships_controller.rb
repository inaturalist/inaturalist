class FriendshipsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_record, only: [:update, :destroy]
  before_filter :require_owner, only: [:update, :destroy]

  layout "bootstrap"

  def index
    @friendships = current_user.friendships.page( params[:page] )
    if @q = params[:q]
      @friendships = @friendships.joins( :friend ).where( "users.login ilike ?", "%#{@q}%" )
    end
    @friendships = @friendships.where( "following" ) if params[:following] && params[:following].yesish?
    @friendships = @friendships.where( "trust" ) if params[:trusted] && params[:trusted].yesish?
    @order = params[:order]
    @order = "desc" unless %w(asc desc).include?( @order )
    @order_by = params[:order_by]
    @order_by = "date" unless %w(date user).include?( @order_by )
    @friendships = if @order_by == "user"
      @friendships.joins(:friend).order( "users.login #{@order}" )
    else
      @friendships.order( "friendships.id #{@order}" )
    end
    respond_to do |format|
      format.html
    end
  end

  def update
    # render_404 unless @friendship = Friendship.find_by_id( params[:id] )
    @friendship.update_attributes( approved_params )
    respond_to do |format|
      format.html { redirect_back_or_default( person_path( current_user ) ) }
      format.json { render json: { friendship: @friendship } }
    end
  end

  def destroy
    @friendship.destroy
    respond_to do |format|
      format.html { redirect_back_or_default( person_path( current_user ) ) }
      format.json { head :no_content }
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
