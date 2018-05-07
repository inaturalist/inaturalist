class ObservationPhotosController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :show, :create, :update, :destroy ], :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  before_filter :load_record, :only => [:destroy]
  before_filter :require_owner, :only => [:destroy]
  
  def show
    @observation_photo = ObservationPhoto.find_by_id(params[:id])
    respond_to do |format|
      format.json do
        render :json => @observation_photo.as_json(:include => {
          :photo => Photo.default_json_options
        })
      end
    end
  end
  
  def create
    unless params[:observation_photo].is_a?( Hash )
      respond_to do |format|
        format.json do
          render json: { errors: "No observation_photo specified" }, status: :unprocessable_entity
        end
      end
      return
    end
    @observation_photo = if !params[:observation_photo].blank? && !params[:observation_photo][:uuid].blank?
      ObservationPhoto.joins(:observation).
        where("observations.user_id = ? AND observation_photos.uuid = ?", current_user, params[:observation_photo][:uuid]).
        first
    end
    @observation_photo ||= ObservationPhoto.new
    @observation_photo.assign_attributes(params[:observation_photo] || {})
    unless @observation_photo.observation
      respond_to do |format|
        format.json do
          if params[:observation_photo] && params[:observation_photo][:observation_id]
            Rails.logger.error "[ERROR #{Time.now}] Observation hasn't been added to #{@site.name}"
            render :json => {:errors => "Observation hasn't been added to #{@site.name}"},
              :status => :unprocessable_entity
          else
            Rails.logger.error "[ERROR #{Time.now}] No observation specified"
            render :json => {:errors => "No observation specified"}, :status => :unprocessable_entity
          end
        end
      end
      return
    end
    if params[:file]
      @photo = LocalPhoto.new(:file => params[:file], :user => current_user, :mobile => is_mobile_app?)
      @photo.save
      @observation_photo.photo = @photo
    end
    
    unless @observation_photo.photo && @observation_photo.photo.valid?
      respond_to do |format|
        Rails.logger.error "[ERROR #{Time.now}] Failed to create observation photo, params: #{params.inspect}"
        format.json { render :json => {:errors => "No photo specified"}, :status => :unprocessable_entity }
      end
      return
    end
    
    begin
      @observation_photo.save
    rescue PG::UniqueViolation => e
      raise e unless e.message =~ /index_observation_photos_on_uuid/
      @observation_photo.errors.add( :uuid, :taken )
    end
    
    respond_to do |format|
      format.json do
        Observation.refresh_es_index
        if @observation_photo.valid?
          render :json => @observation_photo.to_json(:include => [:photo])
        else
          msg = "Failed to create observation photo: #{@observation_photo.errors.full_messages.to_sentence}"
          # Airbrake.notify(Exception.new(msg), :request => request, :session => session)
          Logstasher.write_exception(Exception.new(msg), request: request, session: session, user: current_user)
          Rails.logger.error "[ERROR #{Time.now}] #{msg}"
          render :json => {:errors => @observation_photo.errors.full_messages.to_sentence}, 
            :status => :unprocessable_entity
        end
      end
    end
  end
  
  def update
    unless @observation_photo = ObservationPhoto.find_by_id( params[:id] )
      return create
    end
    return unless require_owner

    @observation_photo.photo.file = params[:file] if params[:file]
    respond_to do |format|
      if @observation_photo.update_attributes(params[:observation_photo])
        @observation_photo.observation.elastic_index!
        Observation.refresh_es_index
        format.json { render :json => @observation_photo.to_json(:include => [:photo]) }
      else
        Rails.logger.error "[ERROR #{Time.now}] Failed to update observation photo: #{@observation_photo.errors.full_messages.to_sentence}"
        format.json do
          render :json => {:errors => @observation_photo.errors.full_messages.to_sentence}, 
            :status => :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @observation_photo.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Observation photo destroyed"
        redirect_to @observation_photo.observation
      end
      format.json  { head :ok }
    end
  end

  private

  def require_owner
    if @observation_photo.observation && @observation_photo.observation.user_id != current_user.id
      msg = "You don't have permission to do that"
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to record
        end
        format.json do
          render json: { error: msg }, status: :unprocessable_entity
        end
      end
      return false
    end
  end
  true
end
