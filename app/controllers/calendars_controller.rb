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
      @observations = @observations.includes(
        :flags,
        :quality_metrics,
        :stored_preferences,
        { taxon: { taxon_names: :place_taxon_names } },
        { photos: :flags }
      )
      if @selected_user != current_user && current_user && current_user.in_test_group?( "interpolation" )
        filtered_obs = @observations.select {|o| o.coordinates_viewable_by?( current_user )}
        diff = @observations.total_entries - filtered_obs.size
        @observations = WillPaginate::Collection.create( 1, 200, @observations.total_entries - diff ) do |pager|
          pager.replace( filtered_obs )
        end
      end
      @taxa = @observations.map{|o| o.taxon}.uniq.compact
      @taxa_count = @taxa.size
      @taxa_by_iconic_taxon_id = @taxa.group_by{|t| t.iconic_taxon_id}
      @iconic_taxon_counts = Taxon::ICONIC_TAXA.map do |iconic_taxon|
        next unless @taxa_by_iconic_taxon_id[iconic_taxon.id]
        [iconic_taxon.id, @taxa_by_iconic_taxon_id[iconic_taxon.id].size]
      end.compact
      @life_list_firsts = @selected_user.taxa_unobserved_before_date( Date.parse( @date ), @taxa ).
        sort_by{|t| t.ancestry || "" }
    else
      iconic_counts_conditions = Observation.conditions_for_date("observations.observed_on", @date)
      iconic_counts_conditions[0] += " AND observations.user_id = ?"
      iconic_counts_conditions << @selected_user
      @iconic_counts = Taxon.joins(:observations).
        where(iconic_counts_conditions).
        group("taxa.iconic_taxon_id").count
    end

    unless @observations.blank?
      @place_name_counts = {}
      @places = Set.new
      Observation.preload_associations( @observations, observations_places: :place )
      @observations.each do |o|
        if @selected_user == current_user
          acc = o.positional_accuracy
        else
          next if o.latitude.blank?
          acc = o.public_positional_accuracy || o.positional_accuracy
        end
        lat = o.private_latitude || o.latitude
        lon = o.private_longitude || o.longitude
        places = o.observations_places.map(&:place).select do |p|
           if p.blank? || ( p.admin_level.blank? && p.place_type != Place::OPEN_SPACE )
            false
          elsif p.straddles_date_line?
            true
          else
            p.bbox_contains_lat_lng_acc?( lat, lon, acc )
          end
        end
        @places += places
        places.each do |p|
          @place_name_counts["#{p.display_name}-#{p.id}"] ||= { place: p, count: 0 }
          @place_name_counts["#{p.display_name}-#{p.id}"][:count] += 1
        end
      end
      @place_name_counts = @place_name_counts.sort_by{ |k,v| v[:place].bbox_area }.map{ |k,v| [k, v[:count]] }[0..5]
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
