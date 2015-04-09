module Shared::GuideModule
  GUIDE_PARTIALS = %w(guide_taxa identotron_taxa)
  
  def show_guide
    filter_param_keys = [:colors, :taxon, :q, :establishment_means, 
      :conservation_status, :threatened, :introduced, :native]
    @filter_params = Hash[params.select{|k,v| 
      is_filter_param = filter_param_keys.include?(k.to_sym)
      is_blank = if v.is_a?(Array) && v.size == 1
        v[0].blank?
      else
        v.blank?
      end
      is_filter_param && !is_blank
    }].symbolize_keys
    @scope = Taxon.active.of_rank_equiv(10)

    if block_given?
      @scope = yield(@scope)
    end

    if @q = @filter_params[:q]
      @search_taxon_ids = Taxon.elastic_search(
        where: { "names.name": @q }, fields: :id).per_page(1000).map(&:id)
      if @search_taxon_ids.size == 1
        @taxon = Taxon.find_by_id(@search_taxon_ids.first)
      elsif Taxon.where(id: @search_taxon_ids).where("name LIKE ?", "#{@q.capitalize}%").count == 1
        @taxon = Taxon.where(name: @q.capitalize).first
      else
        @scope = @scope.among(@search_taxon_ids)
      end
    end
    
    if @filter_params[:taxon]
      @taxon = Taxon.find_by_id(@filter_params[:taxon].to_i) if @filter_params[:taxon].to_i > 0
      @taxon ||= TaxonName.where("lower(name) = ?", @filter_params[:taxon].to_s.strip.gsub(/[\s_]+/, ' ').downcase).
        first.try(:taxon)
    end
    if @taxon
      @scope = if @taxon.species_or_lower? 
        @scope.self_and_descendants_of(@taxon)
      else
        @scope.descendants_of(@taxon)
      end
      @order = "ancestry, taxa.id"
    end
    
    if @colors = @filter_params[:colors]
      @scope = @scope.colored(@colors)
    end
    
    if @threatened = (params[:threatened] == "1")
      @scope = if @place
        @scope.threatened_in_place(@place)
      else
        @scope.threatened
      end
    elsif @conservation_status = @filter_params[:conservation_status]
      @scope = if @place
        @scope.has_conservation_status_in_place(@conservation_status, @place)
      else
        @scope.has_conservation_status(@conservation_status)
      end
    end
    
    page = (params[:page] || 1).to_i
    per_page = 50
    offset = (page - 1) * per_page
    total_entries = @scope.count
    @scope = @scope.select("taxa.*, listed_taxa.id as listed_taxon_id, listed_taxa.observations_count").distinct("taxa.id")
    @paged_scope = @scope.order(@order).limit(per_page).offset(offset)
    @paged_scope = @paged_scope.has_photos if @filter_params.blank?
    Taxon.preload_associations(@paged_scope, [
      { taxon_photos: :photo }, 
      { taxon_names: :place_taxon_names},
      :conservation_statuses, 
      :taxon_descriptions, 
      {taxon_scheme_taxa: :taxon_scheme}
    ])
    @taxa = WillPaginate::Collection.create(page, per_page, total_entries) do |pager|
      pager.replace(@paged_scope.to_a)
    end
    @taxa_by_taxon_id = @taxa.index_by{|t| t.id}
    
    @partial = params[:partial]
    @partial = "guide_taxa" unless GUIDE_PARTIALS.include?(@partial)
    @partial = "guides/#{@partial}"
  end
  
  def show_guide_widget
    @headless = @footless = true
    browsing_taxon_ids = Taxon::ICONIC_TAXA.map{|it| it.ancestor_ids + [it.id]}.flatten.uniq
    browsing_taxa = Taxon.where(id: browsing_taxon_ids).where("name != 'Life'").
      order(:ancestry).includes(:taxon_names)
    @arranged_taxa = Taxon.arrange_nodes(browsing_taxa)
    @grid = params[:grid]
    @grid = "grid" unless %w(grid fluid).include?(@grid)
    @size = params[:size]
    @size = "medium" unless %w(small medium).include?(@size)
    @labeled = params[:labeled]
    @labeld = nil unless params[:labeled] == 'unlabeled'
  end
end
