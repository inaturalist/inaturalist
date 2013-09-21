#encoding: utf-8
class GuidesController < ApplicationController
  include GuidesHelper
  before_filter :authenticate_user!, :except => [:index, :show, :search, :user]
  before_filter :load_record, :only => [:show, :edit, :update, :destroy, :import_taxa, :reorder]
  before_filter :require_owner, :only => [:edit, :update, :destroy, :import_taxa, :reorder]
  before_filter :load_user_by_login, :only => [:user]
  layout "bootstrap"
  PDF_LAYOUTS = GuidePdfFlowTask::LAYOUTS

  caches_page :show, :if => Proc.new {|c| c.request.format == :ngz}
  
  # GET /guides
  # GET /guides.json
  def index
    @guides = Guide.page(params[:page]).order("guides.id DESC")
    if logged_in?
      @guides_by_you = current_user.guides.limit(100).order("guides.id DESC")
    end
    @guides = @guides.near_point(params[:latitude], params[:longitude]) if params[:latitude] && params[:longitude]
    pagination_headers_for(@observations)
    respond_to do |format|
      format.html
      format.json { render json: @guides }
    end
  end

  # GET /guides/1
  # GET /guides/1.json
  def show
    guide_taxa_from_params

    respond_to do |format|
      format.html do
        @guide_taxa = @guide_taxa.page(params[:page]).per_page(100)
        @tag_counts = Tag.joins(:taggings).
          joins("JOIN guide_taxa gt ON gt.id = taggings.taggable_id").
          where("taggings.taggable_type = 'GuideTaxon' AND gt.guide_id = ?", @guide).
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
        
        ancestry_counts_scope = Taxon.joins(:guide_taxa).where("guide_taxa.guide_id = ?", @guide).scoped
        ancestry_counts_scope = ancestry_counts_scope.where(@taxon.descendant_conditions) if @taxon
        ancestry_counts = ancestry_counts_scope.group(:ancestry).count
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
          @nav_taxa_counts = {}
          @nav_taxa.each do |t|
            @nav_taxa_counts[t.id] = @guide.guide_taxa.joins(:taxon).where(t.descendant_conditions).count
          end
        end
      end

      format.json { render json: @guide.as_json(:root => true) }

      format.pdf do
        @layout = params[:layout] if GuidePdfFlowTask::LAYOUTS.include?(params[:layout])
        @layout ||= GuidePdfFlowTask::GRID
        @template = "guides/show_#{@layout}.pdf.haml"
        if params[:print].present?
          render :pdf => "#{@guide.title.parameterize}.#{@layout}", 
            :layout => "bootstrap.pdf",
            :template => @template,
            :orientation => @layout == "journal" ? 'Landscape' : nil,
            :show_as_html => params[:pdf].blank?,
            :margin => {
              :left => 0,
              :right => 0
            }
        elsif params[:flow_task_id] && flow_task = FlowTask.find_by_id(params[:flow_task_id])
          redirect_to flow_task.pdf_url
        else
          matching_flow_task = GuidePdfFlowTask.
            select("DISTINCT ON (flow_tasks.id) flow_tasks.*").
            joins("INNER JOIN flow_task_resources inputs ON inputs.flow_task_id = flow_tasks.id").
            joins("INNER JOIN flow_task_resources outputs ON inputs.flow_task_id = flow_tasks.id").
            where("inputs.type = 'FlowTaskInput'").
            where("outputs.type = 'FlowTaskOutput'").
            where("inputs.resource_type = 'Guide' AND inputs.resource_id = ?", @guide).
            where("outputs.file_file_name IS NOT NULL").
            order("flow_tasks.id DESC").
            detect{|ft| ft.options['layout'] == @layout}
          if matching_flow_task && 
              matching_flow_task.created_at > @guide.updated_at && 
              (matching_flow_task.options['query'].blank? || matching_flow_task.options['query'] == 'all') &&
              !@guide.guide_taxa.where("updated_at > ?", matching_flow_task.created_at).exists? &&
              !GuidePhoto.joins(:guide_taxon).where("guide_taxa.guide_id = ?", @guide).where("guide_photos.updated_at > ?", matching_flow_task.created_at).exists? &&
              !GuideSection.joins(:guide_taxon).where("guide_taxa.guide_id = ?", @guide).where("guide_sections.updated_at > ?", matching_flow_task.created_at).exists? &&
              !GuideRange.joins(:guide_taxon).where("guide_taxa.guide_id = ?", @guide).where("guide_ranges.updated_at > ?", matching_flow_task.created_at).exists?
            redirect_to matching_flow_task.pdf_url
          else
            render :status => :not_found, :text => "", :layout => false
          end
        end
      end
      format.xml do
        @tags = @guide.tags
        @predicates = @tags.map do |tag|
          namespace, predicate, value = FakeView.machine_tag_pieces(tag)
          predicate
        end.compact.uniq.sort
      end
      format.ngz do
        path = "public/guides/#{@guide.to_param}.ngz"
        job_id = Rails.cache.read(@guide.generate_ngz_cache_key)
        job = Delayed::Job.find_by_id(job_id)
        if job
          # Still working
        else
          # no job id, no job, let's get this party started
          Rails.cache.delete(@guide.generate_ngz_cache_key)
          job = @guide.delay.generate_ngz(:path => path)
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
    @nav_options = %w(iconic tag)
    @guide_taxa = @guide.guide_taxa.includes(:taxon, {:guide_photos => :photo}, :tags).
      order("guide_taxa.position")
    @recent_tags = @guide.recent_tags
  end

  # POST /guides
  # POST /guides.json
  def create
    @guide = Guide.new(params[:guide])
    @guide.user = current_user

    respond_to do |format|
      if @guide.save
        create_default_guide_taxa
        format.html { redirect_to edit_guide_path(@guide), notice: 'Guide was successfully created.' }
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
    create_default_guide_taxa
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
    @guide.destroy

    respond_to do |format|
      format.html { redirect_to guides_url, notice: 'Guide deleted.' }
      format.json { head :no_content }
    end
  end

  def import_taxa
    @guide_taxa = @guide.import_taxa(params) || []
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
    @guides = Guide.dbsearch(params[:q]).page(params[:page])
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
    @guides = current_user.guides.page(params[:page]).per_page(500)
    pagination_headers_for(@observations)
    respond_to do |format|
      format.html
      format.json { render :json => @guides }
    end
  end

  private

  def create_default_guide_taxa
    @guide.import_taxa(params)
  end
end
