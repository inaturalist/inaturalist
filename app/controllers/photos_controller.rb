#encoding: utf-8
class PhotosController < ApplicationController
  before_action :doorkeeper_authorize!, only: [:update],
    if: lambda { authenticate_with_oauth? }
  before_filter :load_record, :only => [:show, :update, :repair, :destroy, :rotate]
  before_filter :require_owner, :only => [:update, :destroy, :rotate]
  before_filter :authenticate_user!, except: [:show],
    unless: lambda { authenticated_with_oauth? }
  before_filter :return_here, :only => [:show, :invite, :inviter, :fix]

  cache_sweeper :photo_sweeper, :only => [:update, :repair]
  
  def show
    @size = params[:size]
    @size = "medium" if !%w(small medium large original).include?(@size)
    @size = "small" if @photo.send("#{@size}_url").blank?
    respond_to do |format|
      format.html do
        if params[:partial]
          partial = (params[:partial] || 'photo').split('/').reject(&:blank?).join('/')
          render :layout => false, :partial => partial, :object => @photo, :size => @size
          return
        end
        @taxa = @photo.taxa.limit(100)
        @observations = @photo.observations.limit(100)
        @flags = @photo.flags
      end
      format.js do
        partial = params[:partial] || 'photo'
        render :layout => false, :partial => partial, :object => @photo
      end
    end
  end
  
  def update
    if @photo.update_attributes( photo_params( params[:photo] ) )
      respond_to do |format|
        format.html do
          flash[:notice] = t(:updated_photo)
          redirect_to @photo.becomes(Photo)
        end
        format.json do
          render json: @photo.as_json
        end
      end
    else
      # flash[:error] = t(:error_updating_photo, :photo_errors => @photo.errors.full_messages.to_sentence)
      respond_to do |format|
        format.html do
          flash[:error] = t(:error_updating_photo, :photo_errors => @photo.errors.full_messages.to_sentence)
          redirect_to @photo.becomes(Photo)
        end
        format.json do
          render status: :unprocessable_entity, json: { errors: @photo.errors.as_json }
        end
      end
    end
  end
  
  def local_photo_fields
    # Determine whether we should include synclinks
    @synclink_base = params[:synclink_base] unless params[:synclink_base].blank?
    respond_to do |format|
      format.html do
        render partial: "photos/photo_list_form", locals: {
          photos: [], 
          index: params[:index],
          synclink_base: @synclink_base,
          local_photos: true
        }
      end
    end
  end

  def destroy
    resource = @photo.observations.first || @photo.taxa.first
    @photo.destroy
    flash[:notice] = t(:photo_deleted)
    redirect_back_or_default(resource || '/')
  end

  def fix
    types = %w(FacebookPhoto FlickrPhoto PicasaPhoto)
    @type = params[:type]
    @type = 'FacebookPhoto' unless types.include?(@type)
    @provider_name = @type.underscore.gsub(/_photo/, '')
    @provider_identity = if @provider_name == 'flickr'
      current_user.has_provider_auth('flickr')
    else
      current_user.send("#{@provider_name}_identity")
    end
    @photos = current_user.photos.page(params[:page]).per_page(120).order("photos.id ASC")
    @photos = @photos.where(type: @type)
    respond_to do |format|
      format.html { render layout: 'bootstrap' }
    end
  end

  def repair_all
    @type = params[:type] if %w(FlickrPhoto FacebookPhoto PicasaPhoto).include?(params[:type])
    if @type.blank?
      respond_to do |format|
        format.json do
          msg = "You must specify a photo type"
          flash[:error] = msg
          render status: :unprocessable_entity, json: {error: msg}
        end
      end
      return
    end
    key = "repair_photos_for_user_#{current_user.id}_#{@type}"
    delayed_progress(key) do
      @job = Photo.delay.repair_photos_for_user(current_user, @type)
    end
    respond_to do |format|
      format.json do
        case @status
        when "done"
          flash[:notice] = "Repaired photos"
          render json: {message: "Repaired photos"}
        when "error"
          flash[:error] = @error_msg
          render status: :unprocessable_entity, json: {error: @error_msg}
        else
          render status: :accepted, json: {message: 'In progress...'}
        end
      end
    end
  end

  def repair
    unless @photo.respond_to?(:repair)
      flash[:error] = t(:repair_doesnt_work_for_that_kind_of_photo)
      redirect_back_or_default(@photo.becomes(Photo))
      return
    end

    url = @photo.taxa.first || @photo.observations.first || '/'
    repaired, errors = Photo.repair_single_photo(@photo)
    if repaired.destroyed?
      flash[:error] = t(:photo_destroyed_because_it_was_deleted_from, :site_name => @site.site_name_short)
      redirect_to url
    elsif !errors.blank?
      flash[:error] = t(:failed_to_repair_photo, :errors => errors.values.to_sentence)
      redirect_back_or_default(@photo.becomes(Photo))
    else
      flash[:notice] = t(:photo_urls_repaired)
      redirect_back_or_default(@photo.becomes(Photo))
    end
  end

  def rotate
    unless @photo.is_a?(LocalPhoto)
      flash[:error] = t(:you_cant_rotate_photos_hostde_outside, :site_name => @site.site_name_short)
      redirect_back_or_default(@photo.becomes(Photo))
    end
    rotation = params[:left] ? -90 : 90
    @photo.rotate!(rotation)
    redirect_back_or_default(@photo.becomes(Photo))
  end

  def create
    @photo = LocalPhoto.new(file: params[:file],
      user: current_user, mobile: is_mobile_app?)
    respond_to do |format|
      if @photo.save
        @photo.reload
        format.html { redirect_to observations_path }
        format.json do
          json = @photo.as_json(include: {
            to_observation: {
              include: { observation_field_values:
                { include: :observation_field, methods: :taxon } },
              methods: [ :tag_list ]
            } } )
          json[:original_url] = @photo.file.url(:original)
          json[:large_url] = @photo.file.url(:large)
          render json: json
        end
      else
        format.html { redirect_to observations_path }
        format.json { render json: @photo.errors, status: :unprocessable_entity }
      end
    end
  end

  private
  
  def require_owner
    unless logged_in? && @photo.editable_by?(current_user)
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_to @photo.becomes( Photo )
        end
        format.json do
          return render json: { error: msg }, status: :forbidden
        end
      end
    end
  end

  def photo_params( options = {} )
    p = options.blank? ? params : options
    allowed_fields = Photo::MASS_ASSIGNABLE_ATTRIBUTES + [:license, :license_code]
    p.permit( allowed_fields )
  end

end
