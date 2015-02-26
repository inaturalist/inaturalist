class CalendarsController < ApplicationController
  before_filter :load_user_by_login
  
  def index
    @year = (params[:year] || Time.now.year).to_i
    @observations = @selected_user.observations.on(@year).select(:id, :observed_on)
    @observations_by_month = @observations.group_by {|o| o.observed_on.month}
  end
  
  def show
    @year   = params[:year] if params[:year].to_i != 0
    @month  = params[:month].to_s.rjust(2, '0') if params[:month].to_i != 0
    @day    = params[:day].to_s.rjust(2, '0') if params[:day].to_i != 0
    @date = [@year, @month, @day].compact.join('-')
    begin
      Date.parse(@date)
    rescue ArgumentError
      respond_to do |format|
        format.html do
          flash[:notice] = t(:thats_not_a_real_date)
          redirect_back_or_default calendar_path(@login)
        end
      end
      return
    end
    @observations = @selected_user.observations.
      on(@date).
      page(1).
      per_page(200).
      order_by("observed_on")
    if @day
      @observations = @observations.includes(:taxon => :taxon_names, :observation_photos => :photo)
      @taxa = @observations.map{|o| o.taxon}.uniq.compact
      @taxa_count = @taxa.size
      @taxa_by_iconic_taxon_id = @taxa.group_by{|t| t.iconic_taxon_id}
      @iconic_taxon_counts = Taxon::ICONIC_TAXA.map do |iconic_taxon|
        next unless @taxa_by_iconic_taxon_id[iconic_taxon.id]
        [iconic_taxon.id, @taxa_by_iconic_taxon_id[iconic_taxon.id].size]
      end.compact
    else
      iconic_counts_conditions = Observation.conditions_for_date("observations.observed_on", @date)
      iconic_counts_conditions[0] += " AND observations.user_id = ?"
      iconic_counts_conditions << @selected_user
      @iconic_counts = Taxon.joins(:observations).
        where(iconic_counts_conditions).
        group("taxa.iconic_taxon_id").count
    end
    
    @life_list_firsts = @selected_user.life_list.listed_taxa.where(first_observation_id: @observations).
      sort_by{|lt| lt.ancestry.to_s + '/' + lt.id.to_s}
    
    unless @observations.blank?
      # without this there can be performance problems with very large places.
      # 6 is around the max size for a US county
      place_name_counts = Observation.
        joins("JOIN place_geometries ON (ST_Intersects(place_geometries.geom, observations.private_geom))").
        joins("JOIN places ON (place_geometries.place_id = places.id)").
        where("st_area(place_geometries.geom) < 6").
        where(Observation.conditions_for_date("observations.observed_on", @date)).
        where("observations.user_id = ?", @selected_user).
        group("(places.display_name || '-' || places.id)").count
      @places = Place.where("id IN (?)", place_name_counts.map{|n,c| n.to_s.split('-').last})
      @place_name_counts = @places.sort_by(&:bbox_area).map do |place|
        n = "#{place.display_name}-#{place.id}"
        [n, place_name_counts[n]]
      end
      @previous = @selected_user.observations.where("observed_on < ?", @observations.first.observed_on).order("observed_on DESC").first
      @next = @selected_user.observations.where("observed_on > ?", @observations.first.observed_on).order("observed_on ASC").first
    end

    @observer_provider_authorizations = @selected_user.provider_authorizations

    respond_to do |format|
      format.html
    end
  end
  
  def compare
    @dates = params[:dates].split(',')
    if @dates.blank?
      flash[:notice] = t(:you_must_select_dates_to_compare)
      redirect_back_or_default(calendar_path(@login))
    end
    @observations_by_date_by_taxon_id = {}
    @taxon_ids = []
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i) unless params[:taxon_id].blank?
    scope = Observation.includes(:iconic_taxon)
    scope = scope.of(@taxon) if @taxon
    scope = scope.at_or_below_rank(params[:rank]) if params[:rank]
    @dates.each do |date|
      observations = scope.by(@selected_user).on(date).all
      @taxon_ids += observations.map{|o| o.taxon_id}
      @observations_by_date_by_taxon_id[date] = observations.group_by{|o| o.taxon_id}
    end
    @taxa = Taxon.where(id: @taxon_ids.uniq.compact).includes(:taxon_names)
    @taxa = Taxon.sort_by_ancestry(@taxa)
  end
end
