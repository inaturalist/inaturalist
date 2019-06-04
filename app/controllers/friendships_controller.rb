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
    @trusted = params[:trusted]
    @trusted = "any" unless %w(yes no any).include?( @trusted )
    @following = params[:following]
    @following = "any" unless %w(yes no any).include?( @following )
    if @following == "yes"
      @friendships = @friendships.where( "following" )
    elsif @following == "no"
      @friendships = @friendships.where( "NOT following" )
    end
    if @trusted == "yes"
      @friendships = @friendships.where( "trust" )
    elsif @trusted == "no"
      @friendships = @friendships.where( "NOT trust" )
    end
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
    if @friendship.update_attributes( approved_params )
      respond_to do |format|
        format.html { redirect_back_or_default( person_path( current_user ) ) }
        format.json { render json: { friendship: @friendship } }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = @friendship.errors.full_messages.to_sentence
          redirect_back_or_default( person_path( current_user ) )
        end
        format.json { render status: :unprocessable_entity, json: @friendship.errors.full_messages.to_sentence }
      end
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
