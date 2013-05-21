class GuidesController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_filter :admin_required
  
  # GET /guides
  # GET /guides.json
  def index
    @guides = Guide.page(1)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: {:guides => @guides.as_json} }
    end
  end

  # GET /guides/1
  # GET /guides/1.json
  def show
    @guide = Guide.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @guide.as_json(:root => true) }
    end
  end

  # GET /guides/new
  # GET /guides/new.json
  def new
    @guide = Guide.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @guide.as_json(:root => true) }
    end
  end

  # GET /guides/1/edit
  def edit
    @guide = Guide.find(params[:id])
  end

  # POST /guides
  # POST /guides.json
  def create
    @guide = Guide.new(params[:guide])
    @guide.user = current_user

    respond_to do |format|
      if @guide.save
        create_default_guide_taxa
        format.html { redirect_to @guide, notice: 'Guide was successfully created.' }
        format.json { render json: @guide.as_json(:root => true), status: :created, location: @guide }
      else
        format.html { render action: "new" }
        format.json { render json: @guide.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /guides/1
  # PUT /guides/1.json
  def update
    @guide = Guide.find(params[:id])

    respond_to do |format|
      if @guide.update_attributes(params[:guide])
        format.html { redirect_to @guide, notice: 'Guide was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @guide.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /guides/1
  # DELETE /guides/1.json
  def destroy
    @guide = Guide.find(params[:id])
    @guide.destroy

    respond_to do |format|
      format.html { redirect_to guides_url }
      format.json { head :no_content }
    end
  end

  private

  def create_default_guide_taxa
    return if params[:place_id].blank? && params[:list_id].blank? && params[:taxon_id].blank?
    scope = if !params[:place_id].blank?
      Taxon.from_place(params[:place_id]).scoped
    elsif !params[:list_id].blank?
      Taxon.on_list(params[:list_id]).scoped
    else
      Taxon.scoped
    end
    if t = Taxon.find_by_id(params[:taxon_id])
      scope = scope.descendants_of(t)
    end
    scope.limit(100).each do |taxon|
      gt = @guide.guide_taxa.build(
        :taxon_id => taxon.id,
        :name => taxon.name,
        :display_name => taxon.default_name.name
      )
      if p = taxon.default_photo
        gt.guide_photos.build(:photo => p)
      end
      unless taxon.wikipedia_summary.blank?
        gt.guide_sections.build(:title => "Summary", :description => taxon.wikipedia_summary)
      end
      unless gt.save
        Rails.logger.error "[ERROR #{Time.now}] Failed to save #{gt}: #{gt.errors.full_messages.to_sentence}"
      end
    end
  end
end
