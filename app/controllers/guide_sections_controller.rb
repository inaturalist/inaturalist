class GuideSectionsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_record, :only => [:show, :edit, :update, :destroy]
  before_filter :load_guide, :except => [:index, :new, :create, :import, :import_from_eol, :import_from_wikipedia]
  before_filter :only => [:edit, :update, :destroy] do |c|
    require_guide_user
  end
  check_spam only: [:create, :update], instance: :guide_section

  # GET /guide_sections
  # GET /guide_sections.json
  def index
    @guide_sections = GuideSection.page(params[:page]).per_page(100)
    @guide_sections = @guide_sections.where("id IN (?)", params[:ids]) unless params[:ids].blank?

    respond_to do |format|
      format.html # index.html.erb
      format.json { render :json => {:guide_sections => @guide_sections.as_json(:root => false)} }
    end
  end

  # GET /guide_sections/1
  # GET /guide_sections/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @guide_section.as_json(:root => true) }
    end
  end

  # GET /guide_sections/new
  # GET /guide_sections/new.json
  def new
    @guide_section = GuideSection.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @guide_section.as_json(:root => true) }
    end
  end

  # GET /guide_sections/1/edit
  def edit
  end

  # POST /guide_sections
  # POST /guide_sections.json
  def create
    @guide_section = GuideSection.new(params[:guide_section])
    @guide_section.creator = current_user
    @guide_section.updater = current_user

    respond_to do |format|
      if @guide_section.save
        format.html { redirect_to @guide_section, notice: 'Guide section was successfully created.' }
        format.json { render json: @guide_section, status: :created, location: @guide_section }
      else
        format.html { render action: "new" }
        format.json { render json: @guide_section.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /guide_sections/1
  # PUT /guide_sections/1.json
  def update
    @guide_section.updater = current_user
    respond_to do |format|
      if @guide_section.update_attributes(params[:guide_section])
        format.html { redirect_to @guide_section, notice: 'Guide section was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @guide_section.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /guide_sections/1
  # DELETE /guide_sections/1.json
  def destroy
    @guide_section = GuideSection.find(params[:id])
    @guide_section.destroy

    respond_to do |format|
      format.html { redirect_to guide_sections_url }
      format.json { head :no_content }
    end
  end

  def import
    provider = params[:provider].to_s.downcase
    @sections = if provider == "eol"
      import_from_eol
    elsif provider == "wikipedia"
      import_from_wikipedia
    else
      import_from_inat
    end
    @sections = (@sections || []).sort_by(&:title)
    respond_to do |format|
      format.json do
        render :json => @sections.as_json(:methods => [:attribution])
      end
    end
  end

  private
  def import_from_eol
    eol = EolService.new(:timeout => 30)
    eol_page_id = params[:eol_page_id]
    if eol_page_id.blank?
      pages = eol.search(params[:q], :exact => true)
      eol_page_id = pages.at('entry/id').try(:content)
    end
    return if eol_page_id.blank?
    page = eol.page(eol_page_id,
      images_per_page: 0,
      maps_per_page: 0,
      texts_per_page: 50,
      videos_per_page: 0,
      sounds_per_page: 0,
      subjects: "all",
      details: true)
    page.remove_namespaces!
    TaxonDescribers::Eol.data_objects_from_page(page).to_a.uniq.map do |data_object|
      GuideSection.new_from_eol_data_object(data_object)
    end
  rescue Timeout::Error, OpenURI::HTTPError => e
    []
  end

  def import_from_wikipedia
    w = WikipediaService.new
    sections = []
    if summary = w.summary(params[:q])
      sections << GuideSection.new(
        :title => I18n.t(:summary),
        :description => "<p>#{summary}</p>",
        :rights_holder => "Wikipedia",
        :license => Observation::CC_BY_SA,
        :source_url => w.url_for_title(params[:q].to_s.gsub(/\s+/, '_'))
      )
    end
    r = w.parse(:page => params[:q], :prop => "sections", :redirects => true)
    return sections if r.at('error')
    r.search('s').each do |s|
      sr = w.parse(:page => s['fromtitle'], :section => s['index'], :noimages => 1, :disablepp => 1)
      next if s.at('error')
      next if sr.at('text').blank?
      txt = Nokogiri::HTML(sr.at('text').inner_text).search('p').to_s.strip
      txt = TaxonDescribers::Wikipedia.clean_html(txt, :strip_references => true)
      next if txt.blank?
      sections << GuideSection.new(
        :title => s['line'],
        :description => txt,
        :rights_holder => "Wikipedia",
        :license => Observation::CC_BY_SA,
        :source_url => w.url_for_title(s['fromtitle'])
      )
    end
    sections
  end

  def import_from_inat
    scope = GuideSection.reusable.original.dbsearch(params[:q]).limit(50)
    scope = scope.where("guide_taxon_id != ?", params[:guide_taxon_id]) unless params[:guide_taxon_id].blank?
    scope.map{|gs| gs.reuse }
  end

  def load_guide
    @guide = @guide_section.guide
  end
end
