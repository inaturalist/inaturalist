class CalendarsController < ApplicationController
  before_filter :load_user_by_login
  
  def index
    @year = (params[:year] || Time.now.year).to_i
    @observations = @selected_user.observations.on(@year).all(:select => "id, observed_on")
    @observations_by_month = @observations.group_by {|o| o.observed_on.month}
  end
  
  def show
    @year = params[:year]
    @month = params[:month]
    @day = params[:day]
    @date = [@year, @month, @day].join('-')
    if @day
      scope = @selected_user.observations.on(@date).scoped({})
      @observations = scope.paginate(:include => [{:taxon => :taxon_names}], :per_page => 500, :page => params[:page])
      @taxa = @observations.map{|o| o.taxon}.uniq.compact
      @taxa_count = @taxa.size
      @taxa_by_iconic_taxon_id = @taxa.group_by{|t| t.iconic_taxon_id}
      @iconic_taxon_counts = Taxon::ICONIC_TAXA.map do |iconic_taxon|
        next unless @taxa_by_iconic_taxon_id[iconic_taxon.id]
        [iconic_taxon.id, @taxa_by_iconic_taxon_id[iconic_taxon.id].size]
      end.compact
    else
      scope = @selected_user.observations.on([@year, @month, @day].join('-')).scoped({})
      @observations = scope.
        paginate(:page => params[:page], :per_page => 500)
      @iconic_counts = Taxon.count(
        :joins => "JOIN observations o ON o.taxon_id = taxa.id", 
        :conditions => [
          "o.user_id = ? AND o.observed_on = ?", @selected_user, [@year, @month, @day].join('-')
        ], 
        :group => "taxa.iconic_taxon_id")
    end
    
    @life_list_firsts = @selected_user.life_list.listed_taxa.all(
      :conditions => ["first_observation_id IN (?)", @observations]
    ).sort_by{|lt| lt.ancestry.to_s + '/' + lt.id.to_s}
    
    @place_name_counts = Observation.count(
      :from => "observations, places, place_geometries", 
      :group => "(places.display_name || '-' || places.id)",
      :conditions => [
        "ST_Intersects(observations.geom, place_geometries.geom) " +
        "AND places.id = place_geometries.place_id " + 
        "AND places.place_type NOT IN (?) " +
        "AND observations.user_id = ? " + 
        "AND observations.observed_on::DATE = ?",
        [Place::PLACE_TYPE_CODES['Country'], Place::PLACE_TYPE_CODES['State']],
        @selected_user,
        @date
      ])
    
    unless @observations.blank?
      @previous = @selected_user.observations.first(:conditions => ["observed_on < ?", @date], :order => "observed_on DESC")
      @next = @selected_user.observations.first(:conditions => ["observed_on > ?", @date], :order => "observed_on ASC")
    end
  end
  
  def compare
    @dates = params[:dates].split(',')
    if @dates.blank?
      flash[:notice] = "You must select dates to compare"
      redirect_back_or_default(calendar_path(@login))
    end
    @observations_by_date_by_taxon_id = {}
    @taxon_ids = []
    @dates.each do |date|
      observations = @selected_user.observations.
        on(date).
        all(:include => [:iconic_taxon])
      @taxon_ids += observations.map{|o| o.taxon_id}
      @observations_by_date_by_taxon_id[date] = observations.group_by{|o| o.taxon_id}
    end
    @taxa = Taxon.all(:conditions => ["id IN (?)", @taxon_ids.uniq.compact], :include => [:taxon_names])
    @taxa = Taxon.sort_by_ancestry(@taxa)
  end
end