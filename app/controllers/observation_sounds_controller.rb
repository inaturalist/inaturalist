class ObservationSoundsController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :show, :create, :update, :destroy ], :if => lambda { authenticate_with_oauth? }
  before_action :authenticate_user!, :unless => lambda { authenticated_with_oauth? }
  before_action :load_record, :only => [:destroy]
  before_action :require_owner, :only => [:destroy]
  
  def show
    @observation_sound = ObservationSound.find_by_id(params[:id])
    respond_to do |format|
      format.json do
        render :json => @observation_sound.as_json
      end
    end
  end
  
  def create
    @observation_sound = if !params[:observation_sound].blank? && !params[:observation_sound][:uuid].blank?
      ObservationSound.joins(:observation).
        where("observations.user_id = ? AND observation_sounds.uuid = ?", current_user, params[:observation_sound][:uuid]).
        first
    end
    @observation_sound ||= ObservationSound.new
    @observation_sound.assign_attributes(params[:observation_sound] || {})
    unless @observation_sound.observation
      respond_to do |format|
        format.json do
          if params[:observation_sound] && params[:observation_sound][:observation_id]
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
      @sound = LocalSound.new(:file => params[:file], :user => current_user )
      @sound.save
      @observation_sound.sound = @sound
    end
    
    unless @observation_sound.sound && @observation_sound.sound.valid?
      respond_to do |format|
        Rails.logger.error "[ERROR #{Time.now}] Failed to create observation sound, params: #{params.inspect}"
        format.json { render :json => {:errors => "No sound specified"}, :status => :unprocessable_entity }
      end
      return
    end
    
    @observation_sound.save
    
    respond_to do |format|
      format.json do
        if @observation_sound.valid?
          render :json => @observation_sound.to_json(:include => [:sound])
        else
          msg = "Failed to create observation sound: #{@observation_sound.errors.full_messages.to_sentence}"
          Logstasher.write_exception(Exception.new(msg), request: request, session: session, user: current_user)
          Rails.logger.error "[ERROR #{Time.now}] #{msg}"
          render :json => {:errors => @observation_sound.errors.full_messages.to_sentence}, 
            :status => :unprocessable_entity
        end
      end
    end
  end
  
  def update
    unless @observation_sound = ObservationSound.find_by_id( params[:id] )
      return create
    end
    require_owner

    @observation_sound.sound.file = params[:file] if params[:file]
    respond_to do |format|
      if @observation_sound.update(params[:observation_sound])
          @observation_sound.observation.elastic_index!
        format.json { render :json => @observation_sound.to_json(:include => [:sound]) }
      else
        Rails.logger.error "[ERROR #{Time.now}] Failed to update observation sound: #{@observation_sound.errors.full_messages.to_sentence}"
        format.json do
          render :json => {:errors => @observation_sound.errors.full_messages.to_sentence}, 
            :status => :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @observation_sound.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Observation sound destroyed"
        redirect_to @observation_sound.observation
      end
      format.json  { head :ok }
    end
  end

  private

  def require_owner
    if @observation_sound.observation && @observation_sound.observation.user_id != current_user.id
      msg = "You don't have permission to do that"
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_to record
        end
        format.json do
          return render :json => {:error => msg}, status: :forbidden
        end
      end
      return false
    end
  end
end
