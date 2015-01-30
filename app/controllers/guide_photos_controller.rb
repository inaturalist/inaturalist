class GuidePhotosController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_record, :only => [:show, :edit, :update, :destroy]
  before_filter :load_guide, :except => [:index, :new, :create]
  before_filter :only => [:edit, :update, :destroy, :edit_photos, :update_photos] do |c|
    require_guide_user
  end

  # GET /guide_photos
  # GET /guide_photos.json
  def index
    @guide_photos = GuidePhoto.all
    @guide_photos = @guide_photos.where(id: params[:ids]) unless params[:ids].blank?

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: {:guide_photos => @guide_photos.as_json(:root => false)} }
    end
  end

  # GET /guide_photos/1
  # GET /guide_photos/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @guide_photo.as_json(:root => true) }
    end
  end

  # GET /guide_photos/new
  # GET /guide_photos/new.json
  def new
    @guide_photo = GuidePhoto.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @guide_photo.as_json(:root => true) }
    end
  end

  # GET /guide_photos/1/edit
  def edit
  end

  # POST /guide_photos
  # POST /guide_photos.json
  def create
    respond_to do |format|
      if @guide_photo.save
        format.html { redirect_to @guide_photo, notice: 'Guide photo was successfully created.' }
        format.json { render json: @guide_photo, status: :created, location: @guide_photo }
      else
        format.html { render action: "new" }
        format.json { render json: @guide_photo.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /guide_photos/1
  # PUT /guide_photos/1.json
  def update
    respond_to do |format|
      if @guide_photo.update_attributes(params[:guide_photo])
        format.html { redirect_to @guide_photo, notice: 'Guide photo was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @guide_photo.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /guide_photos/1
  # DELETE /guide_photos/1.json
  def destroy
    @guide_photo.destroy

    respond_to do |format|
      format.html { redirect_to guide_photos_url }
      format.json { head :no_content }
    end
  end

  private
  def load_guide
    @guide = @guide_section.guide
  end
end
