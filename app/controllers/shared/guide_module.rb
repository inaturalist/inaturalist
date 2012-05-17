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
    @scope = Taxon.of_rank(Taxon::SPECIES).scoped({})
    
    if block_given?
      @scope = yield(@scope)
    end
    
    if @q = @filter_params[:q]
      @q = @q.to_s
      @search_taxon_ids = Taxon.search_for_ids(@q, :per_page => 1000)
      @search_taxon_ids = Taxon.search_for_ids(@q) if @search_taxon_ids.blank?
      if @search_taxon_ids.size == 1
        @taxon = Taxon.find_by_id(@search_taxon_ids.first)
      elsif Taxon.count(:conditions => ["id IN (?) AND name LIKE ?", @search_taxon_ids, "#{@q.capitalize}%"]) == 1
        @taxon = Taxon.first(:conditions => ["name = ?", @q.capitalize])
      else
        @scope = @scope.among(@search_taxon_ids)
      end
    end
    
    if @filter_params[:taxon]
      @taxon = Taxon.find_by_id(@filter_params[:taxon].to_i) if @filter_params[:taxon].to_i > 0
      @taxon ||= TaxonName.first(:conditions => [
        "lower(name) = ?", @filter_params[:taxon].to_s.strip.gsub(/[\s_]+/, ' ').downcase]
      ).try(:taxon)
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
    
    if @threatened = @filter_params[:threatened]
      @scope = @scope.threatened
    elsif @conservation_status = @filter_params[:conservation_status]
      @scope = @scope.has_conservation_status(@conservation_status)
    end
    
    @taxa = @scope.paginate( 
      :select => "DISTINCT ON (ancestry, taxa.id) taxa.*",
      :include => [:taxon_names, {:taxon_photos => :photo}],
      :order => @order,
      :page => params[:page], :per_page => 50)
    @taxa_by_taxon_id = @taxa.index_by{|t| t.id}
    
    @partial = params[:partial]
    @partial = "guide_taxa" unless GUIDE_PARTIALS.include?(@partial)
    @partial = "guides/#{@partial}"
  end
  
  def show_guide_widget
    @headless = @footless = true
    browsing_taxon_ids = Taxon::ICONIC_TAXA.map{|it| it.ancestor_ids + [it.id]}.flatten.uniq
    browsing_taxa = Taxon.all(:conditions => ["id in (?)", browsing_taxon_ids], :order => "ancestry", :include => [:taxon_names])
    browsing_taxa.delete_if{|t| t.name == "Life"}
    @arranged_taxa = Taxon.arrange_nodes(browsing_taxa)
    @grid = params[:grid]
    @grid = "fluid" unless %w(grid fluid).include?(@grid)
    @size = params[:size]
    @size = "medium" unless %w(small medium).include?(@size)
    @labeled = params[:labeled]
    @labeld = nil unless params[:labeled] == 'unlabeled'
  end
end