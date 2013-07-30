class GuidesController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :search]
  before_filter :load_record, :only => [:show, :edit, :update, :destroy, :import_taxa, :reorder]
  before_filter :require_owner, :only => [:edit, :update, :destroy, :import_taxa, :reorder]
  layout "bootstrap"
  PDF_LAYOUTS = GuidePdfFlowTask::LAYOUTS

  # caches_page :show, :if => Proc.new {|c| c.request.format == :pdf && c.request.query_parameters.blank?}
  
  # GET /guides
  # GET /guides.json
  def index
    @guides = Guide.page(params[:page]).order("guides.id DESC")
    if logged_in?
      @guides_by_you = current_user.guides.limit(100).order("guides.id DESC")
    end
    respond_to do |format|
      format.html
      format.json { render json: {:guides => @guides.as_json} }
    end
  end

  # GET /guides/1
  # GET /guides/1.json
  def show
    unless params[:taxon].blank?
      @taxon = Taxon::ICONIC_TAXA_BY_ID[params[:taxon]]
      @taxon ||= Taxon::ICONIC_TAXA_BY_NAME[params[:taxon]]
      @taxon ||= Taxon.find_by_name(params[:taxon]) || Taxon.find_by_id(params[:taxon])
      @taxon = nil if @taxon == @guide.taxon
    end
    @q = params[:q]
    @tags = params[:tags] || []
    @tags << params[:tag] unless params[:tag].blank?
    
    @guide_taxa = @guide.guide_taxa.order("guide_taxa.position").
      includes({:taxon => [:taxon_ranges_without_geom]}, {:guide_photos => :photo}, :guide_sections).
      page(params[:page]).per_page(100)
    @guide_taxa = @guide_taxa.in_taxon(@taxon) if @taxon
    @guide_taxa = @guide_taxa.dbsearch(@q) unless @q.blank?
    @guide_taxa = @guide_taxa.tagged(@tags) unless @tags.blank?
    @view = params[:view] || "grid"

    respond_to do |format|
      format.html do
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
          ancestries = ancestry_counts.map{|a,c| a.split('/')}.sort_by(&:size)
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
          @nav_taxa = Taxon.where("id IN (?)", subconsensus_taxon_ids)
        end
      end

      format.json { render json: @guide.as_json(:root => true) }

      format.pdf do
        @guide_taxa = @guide.guide_taxa.order("guide_taxa.position").
          includes({:taxon => [:taxon_ranges_without_geom]}, :guide_photos, :guide_sections)
        @layout = params[:layout] if GuidePdfFlowTask::LAYOUTS.include?(params[:layout])
        @layout ||= GuidePdfFlowTask::GRID
        @template = "guides/show_#{@layout}.pdf.haml"
        if params[:debug].present?
          render :pdf => "#{@guide.title.parameterize}.#{@layout}", 
            :layout => "bootstrap.pdf",
            :template => @template,
            :orientation => @layout == "journal" ? 'Landscape' : nil,
            :show_as_html => true,
            :margin => {
              :left => 0,
              :right => 0
            }
        elsif matching_flow_task = GuidePdfFlowTask.
            select("DISTINCT ON (flow_tasks.id) flow_tasks.*").
            joins("INNER JOIN flow_task_resources inputs ON inputs.flow_task_id = flow_tasks.id").
            joins("INNER JOIN flow_task_resources outputs ON inputs.flow_task_id = flow_tasks.id").
            where("inputs.type = 'FlowTaskInput'").
            where("outputs.type = 'FlowTaskOutput'").
            where("inputs.resource_type = 'Guide' AND inputs.resource_id = ?", @guide).
            where("outputs.file_file_name IS NOT NULL").
            order("flow_tasks.id DESC").
            detect{|ft| ft.options['layout'] == @layout}
          redirect_to matching_flow_task.outputs.first.file.url
        else
          # # generate flow task
          # flow_task = GuidePdfFlowTask.new(
          #   :user => current_user,
          #   :redirect_url => request.url
          # )
          # flow_task.inputs.build(:resource => @guide)
          # flow_task.options = {'layout' => @layout}
          # flow_task.save!
          # redirect_to run_flow_task_path(flow_task)
          render :status => :not_found, :text => "", :layout => false
        end
      end
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
    @nav_options = %w(iconic tag)
    @guide_taxa = @guide.guide_taxa.includes(:taxon => [:taxon_photos => [:photo]], :guide_photos => [:photo], :tags => {}).
      order("guide_taxa.position")
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
    respond_to do |format|
      format.html
    end
  end

  def reorder
    @guide.reorder_by_taxonomy
    respond_to do |format|
      format.html { redirect_to edit_guide_path(@guide) }
      format.json { render :status => 204 }
    end
  end

  private

  def create_default_guide_taxa
    @guide.import_taxa(params)
  end
end
