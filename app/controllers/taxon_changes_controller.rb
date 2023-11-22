class TaxonChangesController < ApplicationController
  before_action :authenticate_user!, :except => [:index, :show]
  before_action :curator_required, :except => [:index, :show, :commit_for_user, :commit_records, :group]
  before_action :admin_required, :only => [:commit_taxon_change]
  before_action :blocked_by_content_freeze, except: [ :index, :show, :new, :create, :edit, :update ]
  before_action :load_taxon_change, :except => [:index, :new, :create, :group, :analyze_ids]
  before_action :return_here, :only => [:index, :show, :new, :edit, :commit_for_user]

  layout "bootstrap"

  def index
    filter_params = params[:filters] || params
    @committed = filter_params[:committed]
    @types = filter_params[:types]
    @types ||= %w(split merge swap stage drop).map{|t| filter_params[t] == "1" ? t : nil}
    @types.delete_if{|t| t.blank?}
    @types = @types.map{|t| t =~ /^Taxon/ ? t : "Taxon#{t.capitalize}"}
    @iconic_taxon = Taxon.find_by_id(filter_params[:iconic_taxon_id]) unless filter_params[:iconic_taxon_id].blank?
    @source = Source.find_by_id(filter_params[:source_id]) unless filter_params[:source_id].blank?
    @taxon = Taxon.find_by_id(filter_params[:taxon_id].to_i) unless filter_params[:taxon_id].blank?
    @ancestor_taxon = Taxon.find_by_id(filter_params[:ancestor_taxon_id].to_i) unless filter_params[:ancestor_taxon_id].blank?
    @change_group = filter_params[:change_group] unless filter_params[:change_group].blank?
    @taxon_scheme = TaxonScheme.find_by_id(filter_params[:taxon_scheme_id]) unless filter_params[:taxon_scheme_id].blank?
    user_id = filter_params[:user_id] || params[:user_id]
    @user = User.find_by_id(user_id) || User.find_by_login(user_id) unless user_id.blank?

    @change_groups = TaxonChange.select(:change_group).group(:change_group).
      map{ |tc| tc.change_group }.compact.sort
    @taxon_schemes = TaxonScheme.limit(100).sort_by{ |ts| ts.title }
    
    scope = TaxonChange.all
    if @committed == 'Yes'
      scope = scope.committed
    elsif @committed == 'No'
      scope = scope.uncommitted
    end
    scope = scope.types(@types) unless @types.blank?
    scope = scope.change_group(@change_group) if @change_group
    scope = scope.iconic_taxon(@iconic_taxon) if @iconic_taxon
    scope = scope.with_taxon(@taxon) if @taxon
    scope = scope.ancestor_taxon( @ancestor_taxon ) if @ancestor_taxon
    scope = scope.source(@source) if @source
    scope = scope.taxon_scheme(@taxon_scheme) if @taxon_scheme
    scope = scope.by(@user) if @user
    
    @taxon_changes = scope.page(params[:page]).
      select("DISTINCT ON (taxon_changes.id) taxon_changes.*").
      includes(:taxon => [:taxon_names, :photos, :taxon_range_without_geom, :taxon_schemes]).
      includes(:taxa => [:taxon_names, :photos, :taxon_range_without_geom, :taxon_schemes]).
      includes(:source).
      order("taxon_changes.id DESC")

    respond_to do |format|
      format.html do
        @taxa = @taxon_changes.map{|tc| [tc.taxa, tc.taxon]}.flatten
        @swaps = TaxonSwap.committed.joins([ {:taxon => :taxon_schemes}, {:taxa => :taxon_schemes} ]).
          where([ "taxon_changes.taxon_id IN (?) OR taxon_change_taxa.taxon_id IN (?)", @taxa, @taxa ])
        @swaps_by_taxon_id = {}
        @swaps.each do |swap|
          @swaps_by_taxon_id[swap.taxon_id] ||= []
          @swaps_by_taxon_id[swap.taxon_id] << swap
          swap.taxa.each do |taxon|
            @swaps_by_taxon_id[taxon.id] ||= []
            @swaps_by_taxon_id[taxon.id] << swap
          end
        end
      end
      format.json do
        taxon_options = { only: [:id, :name, :rank] }
        render json: @taxon_changes.map{|tc|
          json = tc.as_json( methods: [:type ] )
          json[:input_taxa] = tc.input_taxa.as_json( taxon_options ).compact
          json[:output_taxa] = tc.output_taxa.as_json( taxon_options ).compact
          json
        }
      end
    end
  end
  
  def show
    user_viewed_updates_for( @taxon_change ) if logged_in?
    if @taxon_change.committed?
      @job = @taxon_change.commit_records_job
    else
      @existing = @taxon_change.input_taxa.map do |it|
        TaxonChange.input_taxon(it).all.to_a
      end.flatten.compact.uniq.reject{|tc| tc.id == @taxon_change.id || !tc.committed_on.nil?}
      @upstream_taxon_framework = @taxon_change.input_taxa.detect{|t| t.upstream_taxon_framework}.try(:upstream_taxon_framework)
      if current_user && @upstream_taxon_framework && @upstream_taxon_framework.taxon_curators.count > 0 && @upstream_taxon_framework.taxon_curators.select{|tc| tc.user_id != current_user}
        @curated_upstream_taxon_framework = @upstream_taxon_framework
      end
      @observose_taxon = @taxon_change.input_taxa.detect{|t| t.observose_branch?}.try( :observose_branch? )
      @observose_taxon_threshold = Taxon::NUM_OBSERVATIONS_REQUIRING_ADMIN_TO_COMMIT_TAXON_CHANGES
      @observose_taxon_warning = @taxon_change.input_taxa.detect{|t| t.observose_warning_branch?}.try( :observose_warning_branch? )
      @observose_taxon_warning_threshold = Taxon::NUM_OBSERVATIONS_TRIGGERING_WARNING
    end
    respond_to do |format|
      format.html
    end
  end
  
  def new
    @change_groups = TaxonChange.select(:change_group).group(:change_group).map{|tc| tc.change_group}.compact.sort
    @klass = Object.const_get(params[:type]) rescue nil
    @klass = TaxonSwap if @klass.blank? || @klass.superclass != TaxonChange
    @taxon_change = @klass.new
    @input_taxa = Taxon.where("id in (?)", params[:input_taxon_ids])
    @output_taxa = Taxon.where("id in (?)", params[:output_taxon_ids])
    @input_taxa.each {|t| @taxon_change.add_input_taxon(t)} unless @input_taxa.blank?
    @output_taxa.each {|t| @taxon_change.add_output_taxon(t)} unless @output_taxa.blank?
    respond_to do |format|
      format.html { render layout: "application" }
    end
  end
  
  def create
    unless change_params = get_change_params
      flash[:error] = "No changes specified"
      redirect_back_or_default(taxon_changes_url)
      return
    end
    model = change_params.delete(:type).constantize
    @taxon_change = model.new(change_params)
    @taxon_change.user = current_user
    if @taxon_change.save
      flash[:notice] = 'Taxon Change was successfully created.'
      redirect_to action: "show", id: @taxon_change
    else
      @change_groups = TaxonChange.select(:change_group).group(:change_group).map{|tc| tc.change_group}.compact.sort
      render action: "new", layout: "application"
    end
  end
  
  def edit
    @change_groups = TaxonChange.select(:change_group).group(:change_group).map{|tc| tc.change_group}.compact.sort
    respond_to do |format|
      format.html { render layout: "application"}
    end
  end

  def update
    unless change_params = get_change_params
      flash[:error] = "No changes specified"
      redirect_back_or_default(@taxon_change)
      return
    end
    if @taxon_change.update(change_params)
      flash[:notice] = 'Taxon Change was successfully updated.'
      redirect_to taxon_change_path(@taxon_change)
      return
    else
      @change_groups = TaxonChange.select(:change_group).group(:change_group).map{|tc| tc.change_group}.compact.sort
      render action: "edit", layout: "application"
    end
  end
  
  def destroy
    if @taxon_change.committed?
      flash[:error] = t(:committed_taxon_changes_cannot_be_deleted)
      return redirect_back_or_default( taxon_changes_path )
    end
    if @taxon_change.destroy
      flash[:notice] = "Taxon change was deleted."
    else
      flash[:error] = "Something went wrong deleting the taxon change '#{@taxon_change.id}'!"
    end
    redirect_to :action => 'index'
  end
  
  def commit
    if @taxon_change.committed?
      flash[:error] = "This taxonomic change was already committed!"
      redirect_back_or_default(taxon_changes_path)
      return
    end
    
    @taxon = @taxon_change.rank_level_conflict?
    if @taxon
      flash[:error] = "Output taxon rank level not coarser than rank level of active children of input taxon #{view_context.link_to( @taxon.name, @taxon )}".html_safe
      redirect_back_or_default( taxon_changes_path )
      return
    end
    
    if !@taxon_change.move_children? && @taxon_change.active_children_conflict?
      flash[:error] = "Input taxon cannot have active children, move them first, or select the 'Move children to output?' option"
      redirect_back_or_default @taxon_change
      return
    end
    
    @taxon_change.committer = current_user
    @taxon_change.commit
    
    flash[:notice] = "Taxon change committed! Records that can be automatically updated will be changed soon."
    redirect_back_or_default(taxon_changes_path)
  end

  def commit_for_user
    if @taxon_change.draft?
      flash[:error] = t(:taxon_change_must_be_committed_to_update_records)
      redirect_back_or_default @taxon_change
      return
    end
    if @taxon_change.input_taxa.blank? || @taxon_change.output_taxa.blank?
      flash[:error] = "Nothing to do for #{@taxon_change.class.name.underscore.humanize.pluralize.downcase}"
      redirect_back_or_default(@taxon_change)
      return
    end
    return unless load_user_content_info
    @counts = {}
    taxon_ids = if params[:for_taxa] == "output"
      @taxon_change.output_taxa.map(&:id)
    else
      @taxon_change.input_taxa.map(&:id)
    end
    @reflections.each do |reflection|
      @counts[reflection.name.to_s] = current_user.send(reflection.name).
        where("#{reflection.table_name}.taxon_id IN (?)", taxon_ids).
        count
    end
    @records = current_user.send(@reflection.name).where("#{@reflection.table_name}.taxon_id IN (?)", taxon_ids).page(params[:page])
    render layout: "bootstrap"
  end

  def commit_records
    if @taxon_change.input_taxa.blank? || @taxon_change.output_taxa.blank?
      flash[:error] = "Nothing to do for #{@taxon_change.class.name.underscore.humanize.pluralize.downcase}"
      redirect_back_or_default( @taxon_change )
      return
    end
    return unless load_user_content_info

    if params[:record_id]
      @record = current_user.send( @reflection.name ).where("#{@reflection.table_name}.id = ?", params[:record_id]).first
      unless @record
        flash[:error] = "Couldn't find that record"
        redirect_back_or_default( @taxon_change )
        return
      end
      @records = [@record]
    elsif params[:record_ids]
      @records = current_user.send(@reflection.name).where( "#{@reflection.table_name}.id IN (?)", params[:record_ids] ).to_a
      if @records.blank?
        flash[:error] = "Couldn't find any of those records"
        redirect_back_or_default( @taxon_change )
        return
      end
    end

    @taxon = Taxon.find_by_id( params[:taxon_id] )
    @taxon = nil unless @taxon_change.output_taxa.include?( @taxon )
    unless @taxon
      flash[:error] = "That taxon isn't an option"
      redirect_back_or_default( @taxon_change )
      return
    end

    updated = 0
    not_updated = 0
    errors = []

    opts = {
      user: current_user, 
      records: @records,
      conditions: @reflection.options[:conditions],
      include: @reflection.options[:include],
      taxon: @taxon
    }
    @taxon_change.update_records_of_class( @reflection.klass, opts ) do |record|
      if record.valid?
        updated += 1
      else
        not_updated += 1
        errors += record.errors.full_messages
      end
    end

    errors.uniq!
    if errors.blank?
      flash[:notice] = "Records updated"
    else
      flash[:error] = "#{not_updated} record(s) failed to update: #{errors.to_sentence.downcase}"
    end
    redirect_back_or_default( @taxon_change )
  end

  def group
    @group = params[:group]
    @taxon_changes = TaxonChange.where( change_group: @group ).page( params[:page] )
    swap_input_taxa = Taxon.joins( taxon_change_taxa: :taxon_change ).
      select( "DISTINCT taxa.*").
      where( "taxon_changes.change_group = ?", @group ).
      where( "taxon_changes.type = 'TaxonSwap'" )
    merge_input_taxa = Taxon.joins( taxon_change_taxa: :taxon_change ).
      select( "DISTINCT taxa.*").
      where( "taxon_changes.change_group = ?", @group ).
      where( "taxon_changes.type = 'TaxonMerge'" )
    split_input_taxa = Taxon.joins( :taxon_changes ).
      select( "DISTINCT taxa.*").
      where( "taxon_changes.change_group = ?", @group ).
      where( "taxon_changes.type = 'TaxonSplit'" )
    @input_taxa_counts = {
      swap: swap_input_taxa.group( "CASE WHEN committed_on IS NULL THEN 'draft' ELSE 'committed' END" ).count,
      merge: merge_input_taxa.group( "CASE WHEN committed_on IS NULL THEN 'draft' ELSE 'committed' END" ).count,
      split: split_input_taxa.group( "CASE WHEN committed_on IS NULL THEN 'draft' ELSE 'committed' END" ).count
    }
    limit = 500
    @input_taxa = swap_input_taxa.limit( limit ).to_a
    @input_taxa += merge_input_taxa.limit( limit - @input_taxa.size ).to_a if @input_taxa.size < limit
    @input_taxa += split_input_taxa.limit( limit - @input_taxa.size ).to_a if @input_taxa.size < limit
    unless @input_taxa.blank?
      @input_taxa = @input_taxa.uniq.sort_by(&:name)
    end
    swap_output_taxa = Taxon.joins( :taxon_changes ).
      select( "DISTINCT taxa.*").
      where( "taxon_changes.change_group = ?", @group ).
      where( "taxon_changes.type = 'TaxonSwap'" )
    merge_output_taxa = Taxon.joins( :taxon_changes ).
      select( "DISTINCT taxa.*").
      where( "taxon_changes.change_group = ?", @group ).
      where( "taxon_changes.type = 'TaxonMerge'" )
    split_output_taxa = Taxon.joins( taxon_change_taxa: :taxon_change ).
      select( "DISTINCT taxa.*").
      where( "taxon_changes.change_group = ?", @group ).
      where( "taxon_changes.type = 'TaxonSplit'" )
    @output_taxa = swap_output_taxa.limit( limit ).to_a
    @output_taxa += merge_output_taxa.limit( limit - @output_taxa.size ).to_a if @output_taxa.size < limit
    @output_taxa += split_output_taxa.limit( limit - @output_taxa.size ).to_a if @output_taxa.size < limit
    @output_taxa_counts = {
      swap: swap_output_taxa.group( "CASE WHEN committed_on IS NULL THEN 'draft' ELSE 'committed' END" ).count,
      merge: merge_output_taxa.group( "CASE WHEN committed_on IS NULL THEN 'draft' ELSE 'committed' END" ).count,
      split: split_output_taxa.group( "CASE WHEN committed_on IS NULL THEN 'draft' ELSE 'committed' END" ).count
    }
    @committed_count = @taxon_changes.where( "committed_on IS NOT NULL ").total_entries
    @uncommitted_count = @taxon_changes.where( "committed_on IS NULL ").total_entries
    unless @output_taxa.blank?
      @output_taxa = @output_taxa.uniq.sort_by(&:name)
    end
    # TODO preload taxon: {taxon_scheme_taxa: taxon_scheme}, taxon_change_taxa: { taxon: atlas }, source
    TaxonChange.preload_associations( @taxon_changes, [
      {
        taxon: [
          :taxon_schemes,
          :taxon_range_without_geom,
          :photos
        ]
      },
      {
        taxa: [
          :taxon_schemes,
          :atlas,
          :taxon_range_without_geom,
          :photos
        ]
      },
      :source
    ] )
    
    input_counts = {}
    [
      swap_input_taxa.pluck(:id),
      merge_input_taxa.pluck(:id),
      split_input_taxa.pluck(:id)
    ].flatten.each { |id| input_counts[id] ||= 0; input_counts[id] += 1 }
    duplicate_input_ids = input_counts.map{ |id, count| Rails.logger.debug "[id, count]: #{[id, count]}"; count > 1 ? id : nil }.compact
    @taxa_with_multiple_changes = Taxon.where( id: duplicate_input_ids )

    respond_to do |format|
      format.html { render layout: "bootstrap" }
    end
  end

  def analyze_ids
    if params[:id] || params[:taxon_change_id]
      load_taxon_change
    elsif params[:input_taxon_id] && params[:output_taxon_ids]
      stub_taxon_split
    else
      respond_to do |format|
        render json: { error: "You must specify a taxon change or taxon IDs" }, status: :unprocessable_entity
      end
      return
    end
    if @taxon_change && @taxon_change.type == "TaxonSplit" && @taxon_change.taxon && @taxon_change.taxon_change_taxa.size > 1
      id_analysis = TaxonSplit.analyze_id_destinations( @taxon_change )

      analysis_header = identification_analysis_with_url( id_analysis[:total_id_count], :total_id_count )
      analysis_table = []
      analysis_table << identification_analysis_with_url( id_analysis[:inside_multiple_count], :inside_multiple_count )
      analysis_table << identification_analysis_with_url( id_analysis[:outside_all_count], :outside_all_count )
      id_analysis[:output_id_counts].reverse.each do |row|
        analysis_table << identification_analysis_with_url( row, :output_id_count )
      end
      analysis_data = {
        analysis_header: analysis_header,
        analysis_table: analysis_table
      }
      response = { json: analysis_data, status: :ok }
    else
      response = { json: I18n.t( :only_curators_can_access_that_page ), status: :unprocessable_entity }
    end
    respond_to do |format|
      format.json { render json: response[:json], status: response[:status] }
    end
  end
  
  private
  def load_taxon_change
    render_404 unless @taxon_change = TaxonChange.where(id: params[:id] || params[:taxon_change_id]).
      includes(
        {taxon: [:taxon_names, :photos, :taxon_range_without_geom, :taxon_schemes]},
        {taxa: [:taxon_names, :photos, :taxon_range_without_geom, :taxon_schemes]},
        :source
      ).first
  end

  def stub_taxon_split
    input_taxon = Taxon.where( id: params[:input_taxon_id].to_i ).first
    output_taxa = Taxon.where( id: params[:output_taxon_ids].map{|i| i.to_i} )
    @taxon_change = TaxonSplit.new
    @taxon_change.taxon = input_taxon
    output_taxa.each { |t| @taxon_change.taxon_change_taxa.build( taxon: t ) }
  end

  def get_change_params
    change_params = params[:taxon_change]
    TaxonChange::TYPES.each {|type| change_params ||= params[type.underscore]}
    change_params
  end

  def load_user_content_info
    @reflections = []
    skip_reflections = %w(identifications update_subscriptions lists taxon_changes taxon_curators)
    has_many_reflections = User.reflections.select{|k,v| v.macro == :has_many}
    has_many_reflections.each do |k, reflection|
      next if skip_reflections.include?(k.to_s)
      # Avoid those pesky :through relats
      next unless reflection.klass.column_names.include?(reflection.foreign_key)
      next unless reflection.klass.column_names.include?('taxon_id')
      @reflections << reflection
    end
    @type = params[:type] || "observations"
    @reflection = @reflections.detect{|r| r.name.to_s == @type}
    if @reflection.blank?
      flash[:error] = "#{@type} isn't a valid type"
      redirect_back_or_default(:action => "index")
      return false
    end
    true
  end

  def identification_analysis_with_url( row, label )
    if row[:id_count] == 0
      url = nil
    else
      observation_params = {
        id: row[:id_obs].join(","), place_id: "any", verifiable: "any"
      }
      url = observations_path( observation_params )
    end
    taxon_url = taxon_path( { id: row[:taxon_id] } )
    if label == :total_id_count
      return { name: row[:name], taxon_id: row[:taxon_id], taxon_url: taxon_url, id_count: row[:id_count], url: url }
    else
      role = nil
      if row[:atlas_id].nil?
        if label == :inside_multiple_count
          atlas_url = nil
          atlas_string = t( :overlapping_atlases )
          role = "warning"
        elsif label == :outside_all_count
          atlas_url = nil
          atlas_string = t( :outside_of_all_atlases )
          role = "warning"
        else
          atlas_url = new_atlas_path( { taxon_id: row[:taxon_id] } )
          atlas_string = t( :not_atlased )
        end
      else
        if row[:atlas_active] == false
          atlas_string = t( :not_atlased )
        else
          atlas_string = t( :atlased )
        end
        atlas_url = atlas_path( row[:atlas_id] )
      end
      return { name: row[:name], taxon_id: row[:taxon_id], taxon_url: taxon_url, id_count: row[:id_count], url: url, atlas_string: atlas_string, atlas_url: atlas_url, role: role }
    end
  end
end
