class GuideRangesController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_filter :load_record, :only => [:show, :edit, :update, :destroy]
  before_filter :load_guide, :except => [:index, :new, :create, :import]
  before_filter :only => [:edit, :update, :destroy] do |c|
    require_guide_user
  end

  # GET /guide_ranges
  # GET /guide_ranges.json
  def index
    @guide_ranges = GuideRange.all
    @guide_ranges = @guide_ranges.where(id: params[:ids]) unless params[:ids].blank?

    respond_to do |format|
      format.html # index.html.erb
      format.json { render :json => {:guide_ranges => @guide_ranges.as_json(:root => false)} }
    end
  end

  # GET /guide_ranges/1
  # GET /guide_ranges/1.json
  def show
    @guide_range = GuideRange.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @guide_range.as_json(:root => true) }
    end
  end

  # GET /guide_ranges/new
  # GET /guide_ranges/new.json
  def new
    @guide_range = GuideRange.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @guide_range.as_json(:root => true) }
    end
  end

  # GET /guide_ranges/1/edit
  def edit
    @guide_range = GuideRange.find(params[:id])
  end

  # POST /guide_ranges
  # POST /guide_ranges.json
  def create
    @guide_range = GuideRange.new(params[:guide_range])

    respond_to do |format|
      if @guide_range.save
        format.html { redirect_to @guide_range, notice: 'Guide range was successfully created.' }
        format.json { render json: @guide_range.as_json(:root => true), status: :created, location: @guide_range }
      else
        format.html { render action: "new" }
        format.json { render json: @guide_range.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /guide_ranges/1
  # PUT /guide_ranges/1.json
  def update
    @guide_range = GuideRange.find(params[:id])

    respond_to do |format|
      if @guide_range.update_attributes(params[:guide_range])
        format.html { redirect_to @guide_range, notice: 'Guide range was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @guide_range.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /guide_ranges/1
  # DELETE /guide_ranges/1.json
  def destroy
    @guide_range = GuideRange.find(params[:id])
    @guide_range.destroy

    respond_to do |format|
      format.html { redirect_to guide_ranges_url }
      format.json { head :no_content }
    end
  end

  def import
    provider = params[:provider].to_s.downcase
    @ranges = if provider == "wikipedia"
      # import_from_wikipedia
    else
      import_from_eol
    end
    @ranges ||= []
    respond_to do |format|
      format.json do
        render :json => @ranges.as_json(:methods => [:attribution])
      end
    end
  end

  def import_from_eol
    eol = EolService.new(:timeout => 30)
    eol_page_id = params[:eol_page_id]
    if eol_page_id.blank?
      pages = eol.search(params[:q], :exact => true)
      eol_page_id = pages.at('entry/id').try(:content)
    end
    return if eol_page_id.blank?
    page = eol.page(eol_page_id, :text => 0, :images => 0, :sounds => 0, :videos => 0, :maps => 50, :subjects => "all", :details => true)
    page.remove_namespaces!
    page.search('dataObject').map {|data_object|
      Rails.logger.debug "[DEBUG] data_object: #{data_object}"
      gr = GuideRange.new_from_eol_data_object(data_object)
      # gr.valid? ? gr : nil
      gr
    }.compact
  rescue Timeout::Error => e
    []
  end

  private
  def load_guide
    @guide = @guide_range.guide
  end
end
