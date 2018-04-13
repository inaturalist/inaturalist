class GuideTaxaController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  load_only = [ :show, :edit, :update, :destroy,
    :edit_photos, :update_photos, :sync ]
  before_filter :load_record, :only => load_only
  before_filter :load_guide, :only => load_only
  blocks_spam :only => load_only, :instance => :guide_taxon
  before_filter :only => [:edit, :update, :destroy, :edit_photos, :update_photos, :sync] do |c|
    require_guide_user
  end
  layout "bootstrap"

  # GET /guide_taxa
  # GET /guide_taxa.json
  def index
    @guide_taxa = GuideTaxon.includes(:guide_photos => [:photo]).page(params[:page]).per_page(200)
    @guide_taxa = @guide_taxa.where(:guide_id => params[:guide_id]) unless params[:guide_id].blank?

    respond_to do |format|
      format.html # index.html.erb
      format.json do
        render :json => {:guide_taxa => @guide_taxa.as_json(
          :root => false, 
          :methods => [:guide_photo_ids, :guide_section_ids, :guide_range_ids],
          :include => [:guide_photos => {:include => [{:photo => Photo.default_json_options}]}]
        )}
      end
    end
  end

  # GET /guide_taxa/1
  # GET /guide_taxa/1.json
  def show
    respond_to do |format|
      format.html do
        @taxon_links = TaxonLink.by_taxon(@guide_taxon.taxon)
        @machine_tags = @guide_taxon.tag_list.select{|t| t =~ /=/}
        @grouped_machine_tags = @machine_tags.inject({}) do |memo, tag|
          predicate, value = tag.split('=')
          memo[predicate] ||= []
          memo[predicate] << value
          memo[predicate] = memo[predicate].sort.uniq
          memo
        end
        @next = @guide.guide_taxa.order("position ASC, id ASC").where("(position > 0 AND position > ?) OR id > ?", @guide_taxon.position, @guide_taxon.id).first
        @prev = @guide.guide_taxa.order("position ASC, id ASC").where("(position > 0 AND position < ?) OR id < ?", @guide_taxon.position, @guide_taxon.id).last
      end
      format.json { render json: @guide_taxon.as_json(:root => true,
        :methods => [:guide_photo_ids, :guide_section_ids, :guide_range_ids]) }
      format.xml
    end
  end

  # GET /guide_taxa/1/edit
  def edit
    load_data_for_edit
    respond_to do |format|
      format.html
    end
  end

  # POST /guide_taxa
  # POST /guide_taxa.json
  def create
    @guide_taxon = GuideTaxon.new(params[:guide_taxon])
    @guide ||= @guide_taxon.guide
    source_guide_taxon = GuideTaxon.find_by_id(params[:guide_taxon_id]) unless params[:guide_taxon_id].blank?
    if source_guide_taxon
      @guide_taxon = source_guide_taxon.reuse
      @guide_taxon.guide = @guide
    end

    respond_to do |format|
      if @guide_taxon.save
        format.html { redirect_to edit_guide_path(@guide_taxon.guide_id), notice: 'Guide taxon was successfully created.' }
        format.json do
          if partial = params[:partial]
            @guide_taxon.html = view_context.render_in_format(:html, partial, :guide_taxon => @guide_taxon)
          end
          render json: @guide_taxon.as_json(:root => true, :methods => [:html]), status: :created, location: @guide_taxon
        end
      else
        format.html { render action: "new" }
        format.json { render json: @guide_taxon.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # PUT /guide_taxa/1
  # PUT /guide_taxa/1.json
  def update
    respond_to do |format|
      if @guide_taxon.update_attributes(params[:guide_taxon])
        format.html { redirect_to @guide_taxon, notice: 'Guide taxon was successfully updated.' }
        format.json { render :json => @guide_taxon.as_json(:root => true, :methods => [:html]) }
      else
        format.html do
          load_data_for_edit
          render action: "edit"
        end
        format.json { render json: @guide_taxon.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /guide_taxa/1
  # DELETE /guide_taxa/1.json
  def destroy
    @guide_taxon.destroy

    respond_to do |format|
      format.html { redirect_to edit_guide_url(@guide_taxon.guide_id), notice: "Taxon removed" }
      format.json { head :no_content }
    end
  end

  def edit_photos
    @resource = @guide_taxon
    @photos = @guide_taxon.guide_photos.sort_by{|tp| tp.id}.map{|tp| tp.photo}
    render :layout => false, :template => "taxa/edit_photos", :locals => {:licensed => true}
  end

  def update_photos
      photos = retrieve_photos
      errors = photos.map do |p|
        p.valid? ? nil : p.errors.full_messages
      end.flatten.compact
      @guide_taxon.photos = photos
      @guide_taxon.save
      if errors.blank?
        flash[:notice] = "Taxon photos updated!"
      else
        flash[:error] = "Some of those photos couldn't be saved: #{errors.to_sentence.downcase}"
      end
      redirect_to edit_guide_taxon_path(@guide_taxon)
  rescue Errno::ETIMEDOUT
    flash[:error] = "Request timed out!"
    redirect_back_or_default(edit_guide_taxon_path(@guide_taxon))
  rescue Koala::Facebook::APIError => e
    raise e unless e.message =~ /OAuthException/
    flash[:error] = "Facebook needs the owner of that photo to re-confirm their connection to #{@site.preferred_site_name_short}."
    redirect_back_or_default(edit_guide_taxon_path(@guide_taxon))
  end

  def sync
    if params[:provider] == "eol"
      @guide_taxon.sync_eol(:photos => true, :ranges => true, :sections => true, :overview => true)
    else
      @guide_taxon.sync_site_content(:photos => true, :summary => true, :names => true)
    end
    respond_to do |format|
      format.html do
        redirect_to edit_guide_taxon_path(@guide_taxon)
      end
    end
  end

  private
  def retrieve_photos
    photo_classes = Photo.subclasses
    photos = []
    photo_classes.each do |photo_class|
      param = photo_class.to_s.underscore.pluralize
      next if params[param].blank?
      params[param].reject {|i| i.blank?}.uniq.each do |photo_id|
        if fp = photo_class.find_by_native_photo_id(photo_id)
          photos << fp 
        elsif photo_class != 'LocalPhoto'
          pp = photo_class.get_api_response(photo_id)
          photos << photo_class.new_from_api_response(pp) if pp
        end
      end
    end
    photos
  end

  def load_guide
    @guide = @guide_taxon.guide if @guide_taxon
    @guide ||= Guide.find_by_id(params[:guide_taxon][:guide_id]) if params[:guide_taxon]
    render_404 unless @guide
  end

  def load_data_for_edit
    @guide = @guide_taxon.guide
    @guide_photos = @guide_taxon.guide_photos.sort_by(&:position)
    @guide_sections = @guide_taxon.guide_sections.sort_by(&:position)
    @recent_tags = @guide.recent_tags
    @recent_photo_tags = @guide.recent_photo_tags
  end

end
