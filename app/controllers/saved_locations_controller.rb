class SavedLocationsController < ApplicationController
  before_action :doorkeeper_authorize!,
    if: lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, unless: lambda { authenticated_with_oauth? }
  before_filter :load_record, only: [:destroy]
  before_filter :require_owner, only: [:destroy]

  def index
    page = params[:page].to_i <= 0 ? 1 : params[:page].to_i
    @saved_locations = current_user.saved_locations.page( params[:page] ).per_page( limited_per_page )
    if params[:q] && !params[:q].blank?
      @saved_locations = @saved_locations.where( "title ilike ?", "%#{params[:q]}%" )
    else
      @saved_locations = @saved_locations.order( "title ASC" )
    end
    respond_to do |format|
      format.json do
        render json: {
          total_results: @saved_locations.total_entries,
          page: page,
          per_page: limited_per_page,
          results: @saved_locations
        }
      end
    end
  end

  def create
    @saved_location = SavedLocation.new( params[:saved_location] )
    @saved_location.user = current_user
    respond_to do |format|
      format.json do
        if @saved_location.save
          render json: @saved_location
        else
          render status: :unprocessable_entity, json: @saved_location.errors
        end
      end
    end
  end

  def destroy
    @saved_location.destroy
    respond_to do |format|
      format.json { head :no_content }
    end
  end

end
