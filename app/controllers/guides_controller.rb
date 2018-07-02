#encoding: utf-8
class GuidesController < ApplicationController
  include GuidesHelper
  before_action :doorkeeper_authorize!, :only => [ :show, :user ], :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, 
    :except => [:index, :show, :search], 
    :unless => lambda { authenticated_with_oauth? }
  load_only = [ :show, :edit, :update, :destroy, :import_taxa,
    :reorder, :add_color_tags, :add_tags_for_rank, :remove_all_tags, :import_tags_from_csv,
    :import_tags_from_csv_template ]
  before_filter :load_record, :only => load_only
  blocks_spam :only => load_only, :instance => :guide
  before_filter :require_owner, :only => [:destroy]
  before_filter :require_guide_user, :only => [
    :edit, :update, :import_taxa, :reorder, :add_color_tags,
    :add_tags_for_rank, :remove_all_tags, :import_tags_from_csv]

  layout "bootstrap"

  caches_page :show, :if => Proc.new {|c| c.request.format == :ngz || c.request.format == :xml}
  
  # GET /guides
  # GET /guides.json
  def index
    @guides = if logged_in? && params[:by] == "you"
      current_user.editing_guides.not_flagged_as_spam.
        limit(100).order("guides.id DESC")
    else
      Guide.not_flagged_as_spam.page(params[:page]).
        per_page(limited_per_page).order("guides.id DESC").published
    end
    @guides = @guides.near_point(params[:latitude], params[:longitude]) if params[:latitude] && params[:longitude]

    @root_place = @site.place if @site
    @place = (Place.find_by_id(params[:place_id]) rescue nil) unless params[:place_id].blank?
    @place ||= @root_place unless logged_in? && params[:by] == "you"
    if @place
      @guides = @guides.joins(:place).where("places.id = ? OR (#{Place.send(:sanitize_sql, @place.descendant_conditions.to_sql)})", @place)
    end

    unless params[:taxon_id].blank?
      @taxon = Taxon.find_by_id(params[:taxon_id])
      if @taxon
        @guides = @guides.joins(:taxon).where("taxa.id = ? OR (#{Taxon.send(:sanitize_sql, @taxon.descendant_conditions.to_sql)})", @taxon)
      end
    end

    nav_places_for_index
    nav_taxa_for_index

    pagination_headers_for(@observations)
    respond_to do |format|
      format.html do
        @guides = @guides.includes(:guide_users)
      end
      format.json { render json: @guides }
    end
  end

  private
  def nav_places_for_index
    if @place
      ancestry_counts_scope = Place.joins("INNER JOIN guides ON guides.place_id = places.id")
      ancestry_counts_scope = ancestry_counts_scope.where(@place.descendant_conditions) if @place
      ancestry_counts = ancestry_counts_scope.group("ancestry || '/' || places.id::text").count
      if ancestry_counts.blank?
        @nav_places = []
      else
        ancestries = ancestry_counts.map{|a,c| a.to_s.split('/')}.sort_by(&:size).select{|a| a.size > 0}
        width = ancestries.last.size
        matrix = ancestries.map do |a|
          a + ([nil]*(width-a.size))
        end
        # start at the right col (lowest rank), look for the first occurrence of
        # consensus within a rank
        consensus_node_id, subconsensus_node_ids = nil, nil
        (width - 1).downto(0) do |c|
          column_node_ids = matrix.map{|ancestry| ancestry[c]}
          if column_node_ids.uniq.size == 1 && !column_node_ids.first.blank?
            consensus_node_id = column_node_ids.first
            subconsensus_node_ids = matrix.map{|ancestry| ancestry[c+1]}.uniq
            break
          end
        end
        @nav_places = Place.where("id IN (?)", subconsensus_node_ids)
        @nav_places = @nav_places.sort_by(&:name)
      end
    else
      @nav_places = Place.continents.order(:name)
    end
    @nav_places_counts = {}
    @nav_places.each do |p|
      @nav_places_counts[p.id] = @guides.joins(:place).where("places.id = ? OR (#{Place.send(:sanitize_sql, p.descendant_conditions.to_sql)})", p).count
    end
    @nav_places_counts.each do |place_id,count|
      @nav_places = @nav_places.to_a.reject{|p| p.id == place_id} if count == 0
    end
  end

  def nav_taxa_for_index
    if @taxon
      ancestry_counts_scope = Taxon.joins("INNER JOIN guides ON guides.taxon_id = taxa.id")
      ancestry_counts_scope = ancestry_counts_scope.where(@taxon.descendant_conditions) if @taxon
      # ancestry_counts = ancestry_counts_scope.group(:ancestry).count
      ancestry_counts = ancestry_counts_scope.group("ancestry || '/' || taxa.id::text").count
      if ancestry_counts.blank?
        @nav_taxa = []
      else
        ancestries = ancestry_counts.map{|a,c| a.to_s.split('/')}.sort_by(&:size).select{|a| a.size > 0 && a[0] == Taxon::LIFE.id.to_s}
        width = ancestries.last.size
        matrix = ancestries.map do |a|
          a + ([nil]*(width-a.size))
        end
        # start at the right col (lowest rank), look for the first occurrence of
        # consensus within a rank
        consensus_taxon_id, subconsensus_taxon_ids = nil, nil
        (width - 1).downto(0) do |c|
          column_taxon_ids = matrix.map{|ancestry| ancestry[c]}
          if column_taxon_ids.uniq.size == 1 && !column_taxon_ids.first.blank?
            consensus_taxon_id = column_taxon_ids.first
            subconsensus_taxon_ids = matrix.map{|ancestry| ancestry[c+1]}.uniq
            break
          end
        end
        @nav_taxa = Taxon.where("id IN (?)", subconsensus_taxon_ids).includes(:taxon_names).sort_by(&:name)
      end
    else
      @nav_taxa = Taxon::ICONIC_TAXA.select{|t| t.rank == Taxon::KINGDOM}
    end
    @nav_taxa_counts = {}
    @nav_taxa.each do |t|
      @nav_taxa_counts[t.id] = @guides.joins(:taxon).where("taxa.id = ? OR (#{Taxon.send(:sanitize_sql, t.descendant_conditions.to_sql)})", t).count
    end
    @nav_taxa_counts.each do |taxon_id,count|
      @nav_taxa.reject!{|t| t.id == taxon_id} if count == 0
    end
  end
  public

  # GET /guides/1
  # GET /guides/1.json
  def show
    unless @guide.published? || @guide.editable_by?(current_user)
      respond_to do |format|
        format.html { render_404 }
        format.any(:xml, :ngz) { render :status => 404, :text => ""}
        format.json { render :json => {:error => "Not found"}, :status => 404 }
      end
      return
    end
    guide_taxa_from_params
    @photo_tag = params['photo-tag']

    respond_to do |format|
      format.html do
        if params[:print].yesish?
          @layout = params[:layout] if Guide::PDF_LAYOUTS.include?(params[:layout])
          @layout ||= Guide::GRID
          @template = "guides/show_#{@layout}.pdf.haml"
          render layout: "bootstrap.pdf",
            template: @template,
            orientation: @layout == "journal" ? 'Landscape' : nil,
            margin: {
              :left => 0,
              :right => 0
            }
          return
        end
        @guide_taxa = @guide_taxa.page(params[:page]).per_page(100)
        GuideTaxon.preload_associations(@guide_taxa, [
          { guide_photos: [ :photo, {taggings: :tag} ] } ])
        @tag_counts = ActsAsTaggableOn::Tag.joins(:taggings).
          joins("JOIN guide_taxa gt ON gt.id = taggings.taggable_id").
          where("taggings.taggable_type = 'GuideTaxon' AND taggings.context = 'tags' AND gt.guide_id = ?", @guide).
          group("tags.name").
          count
        @nav_tags = ActiveSupport::OrderedHash.new
        @tag_counts.each do |tag, count|
          namespace, predicate = nil, "tags"
          nsp, value = tag.split('=')
          if value.blank?
            value = nsp
          else
            namespace, predicate = nsp.to_s.split(':')
            predicate = namespace if predicate.blank?
          end
          @nav_tags[predicate] ||= []
          @nav_tags[predicate] << [tag, value, count]
        end

        photo_tag_counts = ActsAsTaggableOn::Tag.joins(:taggings).
          joins("JOIN guide_photos gp ON gp.id = taggings.taggable_id").
          joins("JOIN guide_taxa gt ON gt.id = gp.guide_taxon_id").
          where("taggings.taggable_type = 'GuidePhoto' AND taggings.context = 'tags' AND gt.guide_id = ?", @guide).
          group("tags.name").
          count
        @photo_tags = photo_tag_counts.keys.sort
        
        ancestry_counts_scope = Taxon.joins(:guide_taxa).where("guide_taxa.guide_id = ?", @guide)
        ancestry_counts_scope = ancestry_counts_scope.where(@taxon.descendant_conditions) if @taxon
        ancestry_counts = ancestry_counts_scope.group(:ancestry).count
        ancestries = ancestry_counts.map{|a,c| a.to_s.split('/')}.sort_by(&:size).select{|a| a.size > 0 && a[0] == Taxon::LIFE.id.to_s}
        if ancestries.blank?
          @nav_taxa = []
          @nav_taxa_counts = {}
        else
          width = ancestries.last.size
          matrix = ancestries.map do |a|
            a + ([nil]*(width-a.size))
          end
          # start at the right col (lowest rank), look for the first occurrence of
          # consensus within a rank
          consensus_taxon_id, subconsensus_taxon_ids = nil, nil
          (width - 1).downto(0) do |c|
            column_taxon_ids = matrix.map{|ancestry| ancestry[c]}
            if column_taxon_ids.uniq.size == 1 && !column_taxon_ids.first.blank?
              consensus_taxon_id = column_taxon_ids.first
              subconsensus_taxon_ids = matrix.map{|ancestry| ancestry[c+1]}.uniq
              break
            end
          end
          subconsensus_taxon_ids.compact!
          @nav_taxa = Taxon.where("id IN (?)", subconsensus_taxon_ids).includes(:taxon_names).sort_by(&:name)
          if @nav_taxa.map(&:rank).compact.uniq.size == 1 && @nav_taxa.first.species?
            @nav_taxa = Taxon.where(id: consensus_taxon_id)
          end
          @nav_taxa_counts = {}
          @nav_taxa.each do |t|
            @nav_taxa_counts[t.id] = @guide.guide_taxa.joins(:taxon).where(t.descendant_conditions).count
          end
        end
      end
      format.json { render json: @guide.as_json(:root => true) }
      format.xml
      format.ngz do
        path = "public/guides/#{@guide.to_param}.ngz"
        job_id = Rails.cache.read(@guide.generate_ngz_cache_key)
        job = Delayed::Job.find_by_id(job_id)
        if job
          # Still working
        else
          # no job id, no job, let's get this party started
          Rails.cache.delete(@guide.generate_ngz_cache_key)
          job = @guide.delay(:priority => USER_INTEGRITY_PRIORITY).generate_ngz(:path => path)
          Rails.cache.write(@guide.generate_ngz_cache_key, job.id, :expires_in => 1.hour)
        end
        prevent_caching
        # Would prefer to use accepted, but don't want to deliver an invlid zip file
        render :status => :no_content, :layout => false, :text => ""
      end
    end
  end

  # GET /guides/new
  # GET /guides/new.json
  def new
    @guide = Guide.new
    unless params[:source_url].blank?
      @guide.source_url = params[:source_url]
      @guide.set_defaults_from_source_url(:skip_icon => true)
    end
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @guide.as_json(:root => true) }
    end
  end

  # GET /guides/1/edit
  def edit
    load_data_for_edit
    respond_to do |format|
      format.html
    end
  end

  # POST /guides
  # POST /guides.json
  def create
    @guide = Guide.new(params[:guide])
    @guide.user = current_user
    @guide.published_at = Time.now if params[:publish]

    respond_to do |format|
      if @guide.save
        create_default_guide_taxa
        format.html { redirect_to edit_guide_path(@guide), notice: t(:guide_was_successfully_created) }
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
    @guide.icon = nil if params[:icon_delete]
    params[:guide] ||= {}
    if params[:publish]
      params[:guide][:publish] = "publish"
    elsif params[:unpublish]
      params[:guide][:publish] = "unpublish"
    end
    create_default_guide_taxa
    respond_to do |format|
      if @guide.update_attributes(guide_params)
        format.html { redirect_to @guide, notice: t("Guide was successfully #{params[:publish] ? 'published' : 'updated'}".downcase.gsub(' ','_')) }
        format.json { head :no_content }
      else
        format.html do
          load_data_for_edit
          render action: "edit"
        end
        format.json { render json: @guide.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /guides/1
  # DELETE /guides/1.json
  def destroy
    if @guide.guide_taxa.count > 100
      @guide.delay(:priority => USER_INTEGRITY_PRIORITY).destroy
      msg = t(:guide_will_be_deleted)
    else
      @guide.destroy
      msg = t(:guide_deleted)
    end

    respond_to do |format|
      format.html { redirect_to guides_url, notice: msg }
      format.json { head :no_content }
    end
  end

  def import_taxa
    begin
      @guide_taxa = @guide.import_taxa(params) || []
    rescue OpenURI::HTTPError => e
      respond_to do |format|
        format.json do
          msg = if params[:eol_collection_url]
            t(:sorry_x_is_not_responding, :x => "EOL")
          else
            t(:sorry_that_service_is_not_responding)
          end
          render :json => {:error => msg}
        end
      end
      return
    end
    respond_to do |format|
      format.json do
        if partial = params[:partial]
          @guide_taxa.each_with_index do |gt, i|
            next if gt.new_record?
            @guide_taxa[i].html = view_context.render_in_format(:html, partial, :guide_taxon => gt)
          end
        end
        render :json => {:guide_taxa => @guide_taxa.as_json(:root => false, :methods => [:errors, :html, :valid?])}
      end
    end
  end

  def search
    @guides = Guide.published.dbsearch(params[:q]).page(params[:page]).per_page(limited_per_page)
    pagination_headers_for @guides
    respond_to do |format|
      format.html
      format.json do
        render :json => @guides
      end
    end
  end

  def reorder
    @guide.reorder_by_taxonomy
    respond_to do |format|
      format.html { redirect_to edit_guide_path(@guide) }
      format.json { render :status => 204 }
    end
  end

  def user
    @guides = current_user.editing_guides.page(params[:page]).per_page(500).order("lower(title)")
    pagination_headers_for(@observations)
    respond_to do |format|
      format.json { render :json => @guides }
    end
  end

  def add_color_tags
    @guide_taxa = @guide.guide_taxa.joins(taxon: :colors).where("colors.id IS NOT NULL")
    @guide_taxa = @guide_taxa.where("guide_taxa.id IN (?)", params[:guide_taxon_ids]) unless params[:guide_taxon_ids].blank?
    @guide_taxa.each do |gt|
      gt.add_color_tags
    end
    respond_to do |format|
      format.json { render :json => @guide_taxa.as_json(:methods => [:tag_list])}
    end
  end

  def add_tags_for_rank
    @guide_taxa = @guide.guide_taxa.includes(:taxon => [:taxon_names])
    @guide_taxa = @guide_taxa.where("guide_taxa.id IN (?)", params[:guide_taxon_ids]) unless params[:guide_taxon_ids].blank?
    @guide_taxa.each do |gt|
      gt.add_rank_tag(params[:rank], :lexicon => params[:lexicon])
    end
    respond_to do |format|
      format.json { render :json => @guide_taxa.as_json(:methods => [:tag_list])}
    end
  end

  def remove_all_tags
    @guide_taxa = @guide.guide_taxa
    @guide_taxa.each do |gt|
      gt.taggings.delete_all
    end
    respond_to do |format|
      format.json { render :json => @guide_taxa.as_json(:methods => [:tag_list])}
    end
  end

  def import_tags_from_csv
    unless params[:file]
      respond_to do |format|
        format.html do
          flash[:error] = "You must choose a CSV file."
          redirect_back_or_default(@guide)
          return
        end
      end
    end
    tags = {}
    row_handler = Proc.new do |row|
      tags[row[0]] ||= []
      row.each_with_index do |pair,i|
        next if i == 0
        header, value = pair
        next if value.blank?
        value.split('|').each do |v|
          if header.blank?
            tags[row[0]] << v
          else
            tags[row[0]] << "#{header}=#{v}"
          end
        end
      end
    end
    begin
      CSV.foreach(open(params[:file]), headers: true, &row_handler)
    rescue ArgumentError => e
      raise e unless e.message =~ /invalid byte sequence in UTF-8/
      # if there's an encoding issue we'll try to load the entire file and adjust the encoding
      content = open(params[:file]).read
      utf_content = if content.encoding.name == 'UTF-8'
        # if Ruby thinks it's UTF-8 but it obviously isn't, we'll assume it's LATIN1
        content.force_encoding('ISO-8859-1')
        content.encode('UTF-8')
      else
        # otherwise we try to coerce it into UTF-8
        content.encode('UTF-8')
      end
      CSV.parse(utf_content, headers: true, &row_handler)
    end

    @guide.guide_taxa.find_each do |gt|
      next unless tags[gt.name]
      gt.update_attributes(tag_list: gt.tag_list + tags[gt.name])
    end
    respond_to do |format|
      format.html { redirect_back_or_default(@guide) }
    end
  end

  def import_tags_from_csv_template
    tags = {}
    headers = Set.new
    @guide.guide_taxa.order(:position).includes(taggings: :tag).each_with_index do |gt,i|
      tags[gt.name] ||= {}
      gt.tags.each do |tag|
        namespace, predicate, value = FakeView.machine_tag_pieces(tag.name)
        header = [namespace, predicate].compact.join(':')
        headers << header
        tags[gt.name][header] = [tags[gt.name][header].to_s.split('|'), value].flatten.join('|')
      end
    end
    headers = headers.to_a.sort
    csvdata = CSV.generate do |csv|
      csv << ['Name', headers].flatten
      tags.each do |name, values_by_headers|
        line = [name]
        headers.each do |header|
          line << values_by_headers[header]
        end
        csv << line
      end
    end
    respond_to do |format|
      format.csv do
        send_data(csvdata, { :filename => "#{@guide.title.parameterize}.csv", :type => :csv })
      end
    end
  end


  private

  def create_default_guide_taxa
    @guide.import_taxa(params)
  end

  def load_data_for_edit
    @nav_options = %w(iconic tag)
    @guide_taxa = @guide.guide_taxa.includes(:taxon, {:guide_photos => :photo}, :tags).
      order("guide_taxa.position")
    @recent_tags = @guide.recent_tags
  end

  def guide_params
    params.require(:guide).permit(
      :description,
      :downloadable,
      :icon,
      :latitude,
      :license,
      :longitude,
      :map_type,
      :place_id,
      :publish,
      :taxon_id,
      :title,
      :zoom_level,
      :guide_users_attributes => [:id, :user_id, :guide_id, :_destroy]
    )
  end
end
