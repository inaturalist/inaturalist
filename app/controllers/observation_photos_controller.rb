class ObservationPhotosController < ApplicationController
  before_filter :login_required
  
  def create
    @observation_photo = ObservationPhoto.new(params[:observation_photo])
    unless @observation_photo.observation
      respond_to do |format|
        format.json do
          if params[:observation_photo] && params[:observation_photo][:observation_id]
            render :json => "Observation hasn't been added to iNaturalist", 
              :status => :unprocessable_entity
          else
            render :json => "No observation specified", :status => :unprocessable_entity
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
        Rails.logger.error "[ERROR #{Time.now}] Failed to creat observation photo: #{@observation_photo.photo.errors.full_messages.to_sentence}"
        format.json { render :json => "No photo specified", :status => :unprocessable_entity }
      end
      return
    end
    
    @observation_photo.save
    
    respond_to do |format|
      format.json do
        if @observation_photo.valid?
          render :json => @observation_photo
        else
          Rails.logger.error "[ERROR #{Time.now}] Failed to create observation photo: #{@observation_photo.errors.full_messages.to_sentence}"
          render :json => @observation_photo.errors, :status => :unprocessable_entity
        end
      end
    end
  end
end
