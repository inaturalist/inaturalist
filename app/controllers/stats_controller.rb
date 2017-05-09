class StatsController < ApplicationController

  before_filter :set_time_zone_to_utc
  before_filter :load_params
  caches_action :summary, expires_in: 1.hour
  caches_action :observation_weeks_json, expires_in: 1.day
  caches_action :nps_bioblitz, expires_in: 5.minutes
  caches_action :cnc2016, expires_in: 5.minutes
  caches_action :cnc2017, expires_in: 5.minutes
  before_filter :authenticate_user!, only: [:cnc2017_taxa, :cnc2017_stats]
  before_filter :allow_external_iframes, only: [:world_environment_day]

  def index
    respond_to do |format|
      format.json {
        fetch_statistics
        render json: @stats, except: :id, callback: params[:callback]
      }
      format.html {
        if params[:start_date].nil?
          @start_date = @end_date - 1.year
        end
        fetch_statistics
        render layout: 'bootstrap'
      }
    end
  end

  def summary
    params = { verifiable: true, per_page: 1 }
    params[:place_id] = @site.place_id if @site.place_id
    observations = INatAPIService.observations(params)
    observers = INatAPIService.observations_observers(params)
    species_counts = INatAPIService.observations_species_counts(params)
    user_count_scope = User.where("suspended_at IS NULL")
    if @site.name != "iNaturalist.org"
      user_count_scope = user_count_scope.where(site_id: @site.id)
    end
    @stats = {
      total_users: user_count_scope.count,
      total_leaf_taxa: (species_counts && species_counts.total_results) || 0,
      total_observations: (observations && observations.total_results) || 0,
      total_observed_taxa: (species_counts && species_counts.total_results) || 0,
      total_observers: (observers && observers.total_results) || 0,
      updated_at: Time.now
    }
    respond_to do |format|
      format.json { render json: @stats}
    end
  end

  def observation_weeks
    render layout: "basic"
  end

  def observation_weeks_json
    render json: observation_weeks_data
  end

  def nps_bioblitz
    @overall_id = 6810
    umbrella_project_ids = [ 6810, 7109, 7110, 7107, 6790 ]
    sub_project_ids = {
      6810 => [ ],
      7109 => [ 6818, 6846, 6864, 7026, 6832, 7069, 6859 ],
      7110 => [ 6835, 6833, 6840, 7298, 6819, 7299, 6815,
        6814, 7025, 7281, 6816, 7302, 7301, 6822 ],
      7107 => [ 6824, 6465, 6478 ],
      6790 => [ 6850, 6851, 7167, 6852, 7168, 7169 ]
    }
    project_slideshow_data( @overall_id, {
      umbrella_project_ids: umbrella_project_ids,
      sub_project_ids: sub_project_ids,
      trim_slackers: true,
      group: Project::NPS_BIOBLITZ_GROUP_NAME,
      title: "NPS Servicewide",
      logo_paths: ["/logo-nps.svg", "/logo-natgeo.svg"]
    } ) do |all_project_data|
      # hard-coding umbrella project places
      all_project_data[6810][:place_id] = 0 if all_project_data[6810]
      all_project_data[7109][:place_id] = 46 if all_project_data[7109]
      all_project_data[7110][:place_id] = 5 if all_project_data[7110]
      all_project_data[7107][:place_id] = 51727 if all_project_data[7107]
      all_project_data[6790][:place_id] = 43 if all_project_data[6790]
      all_project_data.each do |project_id, project|
        all_project_data[project_id][:title] = project[:title].sub( "2016 National Parks BioBlitz - ", "" )
      end
    end
  end

  def cnc2017_taxa
    @projects = Project.where( id: [10931, 11013, 11053, 11126, 10768, 10769, 10752, 10764,
      11047, 11110, 10788, 10695, 10945, 10917, 10763, 11042] )
    # @projects = Project.where( id: [3,4] )
    @project = @projects.detect{ |p| p.id == params[:project_id].to_i }
    if @project
      target_place_id = params[:place_id]
      @target_place = Place.find( target_place_id ) rescue nil
      month = [@project.preferred_start_date_or_time.month, @project.preferred_end_date_or_time.month].uniq
      @potential_params = { month: month.join(","), place_id: @project.rule_places.map(&:id), quality_grade: "research" }
      if @target_place
        @potential_params[:place_id] = @target_place.id
      end
      potential_elastic_params = Observation.params_to_elastic_query( @potential_params )
      potential_leaf_taxon_ids = Observation.elastic_taxon_leaf_ids( potential_elastic_params )
      potential_taxon_ids = (
        potential_leaf_taxon_ids + 
        TaxonAncestor.where( taxon_id: potential_leaf_taxon_ids ).pluck( :ancestor_taxon_id )
      ).uniq
      @in_project_params = { projects: [@project.id] }
      in_project_elastic_params = Observation.params_to_elastic_query( @in_project_params )
      in_project_leaf_taxon_ids = Observation.elastic_taxon_leaf_ids( in_project_elastic_params )
      in_project_taxon_ids = (
        in_project_leaf_taxon_ids + 
        TaxonAncestor.where( taxon_id: in_project_leaf_taxon_ids ).pluck( :ancestor_taxon_id )
      ).uniq
      @missing_taxon_ids = potential_leaf_taxon_ids - in_project_taxon_ids
      @novel_taxon_ids = in_project_leaf_taxon_ids - potential_taxon_ids
      @taxa = if params[:status] == "Missing"
        Taxon.where( is_active: true, id: @missing_taxon_ids )
      elsif params[:status] == "Novel"
        Taxon.where( is_active: true, id: @novel_taxon_ids )
      else
        Taxon.where( is_active: true, id: (@missing_taxon_ids + @novel_taxon_ids).uniq )
      end
      # @taxa.group_by(&:iconic_taxon_id).each do |iconic_taxon_id, group|
      #   iconic_taxon = Taxon::ICONIC_TAXA_BY_ID[iconic_taxon_id]
      #   puts
      #   puts iconic_taxon.name.upcase
      #   puts
      #   # group.sort_by{|t| t.self_and_ancestor_ids.to_s + t.name }.each do |taxon|
      #   group.sort_by{|t| t.observations_count * -1 }.each do |taxon|
      #     if taxon.common_name
      #       puts "#{taxon.common_name.name} (#{taxon.name})"
      #     else
      #       puts taxon.name
      #     end
      #   end
      # end
    end
    respond_to do |format|
      format.html{ render layout: "bootstrap" }
      format.csv do
        csv_text = CSV.generate( headers: true ) do |csv|
          csv << %w{scientific_name common_name iconic_taxon_name status}
          @taxa.each do |t|
            csv << [t.name, t.common_name.try(:name), t.iconic_taxon_name, @missing_taxon_ids.index( t.id ) ? "Missing" : "Novel"]
          end
        end
        render text: csv_text
      end
    end
  end

  def cnc2017
    project_slideshow_data( 11753,
      umbrella_project_ids: [11753],
      sub_project_ids: {
        11753 => [10931, 11013, 11053, 11126, 10768, 10769, 10752, 10764,
          11047, 11110, 10788, 10695, 10945, 10917, 10763, 11042]
      },
      title: "City Nature Challenge 2017"
    ) do |all_project_data|
      all_project_data[11753][:place_id] = 0 if all_project_data[11753]
      all_project_data.each do |project_id, project|
        all_project_data[project_id][:title] = project[:title].sub( "City Nature Challenge 2017: ", "" )
      end
    end
  end

  def cnc2017_stats
    project_ids = [10931, 11013, 11053, 11126, 10768, 10769, 10752, 10764, 11047, 11110, 10788, 10695, 10945, 10917, 10763, 11042]
    # project_ids = [1,2,3,4]
    project_id = params[:project_id] if project_ids.include?( params[:project_id].to_i )
    project_id ||= 11753
    @projects = Project.where( id: project_ids )
    @project = Project.find( project_id )

    # prepare the data needed for the slideshow
    @data = []
    @projects.each do |p|
      node_params = {
        project_id: p.id,
        per_page: 0,
        ttl: 300
      }
      case params[:quality]
      when "research"
        node_params[:quality_grade] = "research"
      when "verifiable"
        node_params[:quality_grade] = "research,needs_id"
      end
      species_count_response = INatAPIService.observations_species_counts( node_params )
      species_count = (species_count_response && species_count_response.total_results) || 0
      observations_count_response = INatAPIService.observations( node_params )
      observations_count = (observations_count_response && observations_count_response.total_results) || 0
      identifiers_count_response = INatAPIService.get( "/observations/identifiers", node_params )
      identifiers_count = (identifiers_count_response && identifiers_count_response.total_results) || 0
      observers_count_response = INatAPIService.get( "/observations/observers", node_params )
      observers_count = (observers_count_response && observers_count_response.total_results) || 0

      # Descriptive stats are cool but really, really slow to calculate
      # sql = <<-SQL
      #   SELECT
      #     slug,
      #     avg( obs_count ),
      #     max( obs_count ),
      #     median( obs_count )
      #   FROM
      #     (
      #       SELECT p.slug, o.user_id, count(*) AS obs_count
      #       FROM observations o JOIN project_observations po ON o.id = po.observation_id JOIN projects p ON p.id = po.project_id
      #       WHERE po.project_id IN (10931, 11013, 11053, 11126, 10768, 10769, 10752, 10764, 11047, 11110, 10788, 10695, 10945, 10917, 10763, 11042)
      #       GROUP BY p.slug, o.user_id
      #     ) AS foo
      #   GROUP BY slug
      # SQL
      
      @data << {
        id: p.id,
        title: p.title.gsub( /City Nature Challenge: /, "" ),
        slug: p.slug,
        observation_count: observations_count,
        in_progress: p.event_in_progress?,
        species_count: species_count,
        observers_count: observers_count,
        identifiers_count: identifiers_count
      }
    end

    @in_project_params = { projects: [@project.id] }
    @in_project_params[:quality_grade] = case params[:quality]
    when "research" then "research"
    when "verifiable" then "research,needs_id"
    end
    in_project_elastic_params = Observation.params_to_elastic_query( @in_project_params )
    in_project_leaf_taxon_ids = Observation.elastic_taxon_leaf_ids( in_project_elastic_params )
    in_project_leaf_taxon_ids = [-1] if in_project_leaf_taxon_ids.blank?
    unique_taxon_ids = Observation.elastic_taxon_leaf_counts( in_project_elastic_params ).map{|taxon_id, count| count == 1 ? taxon_id : nil}.compact.uniq
    @unique_contributors = User.
      select( "users.*, count(*) AS unique_count, array_agg(observations.taxon_id) AS taxon_ids" ).
      joins( observations: :project_observations ).
      where( "project_observations.project_id = ?", @project ).
      where( "observations.taxon_id IN (?)", unique_taxon_ids ).
      group( "users.id" ).
      order( "count(*) DESC" ).
      limit( 100 )
    if params[:quality] == "research"
      @unique_contributors = @unique_contributors.where ( "observations.quality_grade = 'research'" )
    elsif params[:quality] == "verifiable"
      @unique_contributors = @unique_contributors.where ( "observations.quality_grade IN ('research', 'needs_id')" )
    end

    @rank_counts = Observation.
      query( projects: project_ids ).
      joins( :projects ).
      joins( "LEFT OUTER JOIN taxa ON taxa.id = observations.taxon_id" ).
      select( "projects.slug, taxa.rank, count(*)" ).
      group( "projects.slug, taxa.rank" )
    if params[:quality] == "research"
      @rank_counts = @rank_counts.where( quality_grade: "research" )
    elsif params[:quality] == "verifiable"
      @rank_counts = @rank_counts.where( "quality_grade IN ('research', 'needs_id')" )
    end
    @rank_counts = @rank_counts.group_by{|o| o.slug }

    respond_to do |format|
      format.html{ render layout: "bootstrap" }
    end
  end

  def cnc2016
    project_slideshow_data( 11765,
      umbrella_project_ids: [11765],
      sub_project_ids: {
        11765 => [6345, 6365]
      },
      title: "City Nature Challenge 2016"
    ) do |all_project_data|
      all_project_data[11765][:place_id] = 14 if all_project_data[11765]
    end
  end

  def world_environment_day
    render layout: "basic"
  end

  private

  def set_time_zone_to_utc
    Time.zone = "UTC"
  end

  def load_params
    @end_date = Time.zone.parse(params[:end_date]).beginning_of_day rescue Time.now
    @start_date = Time.zone.parse(params[:start_date]).beginning_of_day rescue 1.day.ago
    @start_date = Time.zone.now if @start_date > Time.zone.now
    @end_date = Time.zone.now if @end_date > Time.zone.now
    if SiteStatistic.first_stat && @start_date < SiteStatistic.first_stat.created_at
      @start_date = SiteStatistic.first_stat.created_at
    end
  end

  def fetch_statistics
    @stats = SiteStatistic.where(created_at: @start_date..@end_date).order("created_at desc")
    unless @stats.any?
      @stats = [ SiteStatistic.order("created_at asc").last ]
    end
  end

  def observation_weeks_data
    inner1 = "
      SELECT
        date_trunc( 'week', o.created_at ) AS week,
        user_id,
        count(*) as user_total,
        count(*) over( partition by date_trunc( 'week', o.created_at ) ) as observer_count
      FROM observations o
      WHERE quality_grade IN ( 'research', 'needs_id' )
      GROUP BY date_trunc( 'week', o.created_at ), user_id"
    inner2 = "
      SELECT
        week,
        user_id,
        user_total,
        observer_count,
        rank( ) OVER( partition by week order by user_total desc ) as user_rank,
        sum( user_total ) OVER( partition by week ) as week_total
      FROM (#{ inner1 }) as inner1"
    query = "
      SELECT
        week,
        user_id as id,
        u.login,
        u.icon_file_name,
        u.icon_content_type,
        u.icon_file_size,
        user_total,
        observer_count,
        week_total,
        rank( ) OVER( order by week_total desc ) as week_rank,
        rank( ) OVER( order by user_total desc ) as user_week_rank
      FROM (#{ inner2 }) as inner2
      LEFT JOIN users u ON ( inner2.user_id = u.id )
      WHERE user_rank = 1
      ORDER by week desc"
    weeks_totals = User.find_by_sql(query)
    weeks_totals.map do |r|
      {
        week: r.week,
        user_id: r.id,
        user_login: r.login,
        user_icon: r.medium_user_icon_url,
        user_week_total: r.user_total,
        user_week_rank: r.user_week_rank,
        week_total: r.week_total.to_i,
        week_rank: r.week_rank,
        observer_count: r.observer_count
      }
    end
  end

  def project_slideshow_data( overall_project_id, options = {} )
    umbrella_project_ids = options[:umbrella_project_ids] || []
    sub_project_ids = options[:sub_project_ids] || {}
    @overall_id = overall_project_id
    all_project_ids = (
      sub_project_ids.map{ |k,v| v }.flatten +
      sub_project_ids.keys +
      umbrella_project_ids +
      [overall_project_id]
    ).flatten.uniq

    projs = Project.select("projects.*, count(po.observation_id)").
      joins("LEFT JOIN project_observations po ON (projects.id=po.project_id)").
      group(:id).
      order("count(po.observation_id) desc")
    projs = if options[:group]
      projs.where("projects.group = ? OR projects.id = ? OR projects.id IN (?)", options[:group], params[:project_id], all_project_ids)
    else
      projs.where("projects.id = ? OR projects.id IN (?)", params[:project_id], all_project_ids)
    end

    # prepare the data needed for the slideshow
    begin
      all_project_data = Hash[ projs.map{ |p|
        [ p.id,
          {
            id: p.id,
            title: p.title,
            slug: p.slug,
            start_time: p.start_time,
            end_time: p.end_time,
            place_id: p.rule_place.try(:id),
            observation_count: p.count,
            in_progress: p.event_in_progress?,
            species_count: p.node_api_species_count || 0
          }
        ]
      }]
    rescue => e
      Rails.logger.debug "[DEBUG] error loading project data: #{e}"
      sleep(2)
      return redirect_to :nps_bioblitz_stats
    end

    if block_given?
      yield all_project_data
    end

    # setting the number of slides to show per umbrella project
    umbrella_project_ids.each do |id|
      all_project_data[id][:slideshow_count] = 1 if all_project_data[id]
    end

    if all_project_data[@overall_id]
      # the overall project shows 5 slides
      all_project_data[@overall_id][:title] = options[:title]
      all_project_data[@overall_id][:slideshow_count] = 5
      # the overall project shows any non-umbrella project not already
      # shown under an umbrella project
      sub_project_ids[@overall_id] = all_project_data.keys -
        all_project_ids - sub_project_ids.keys
    end

    # deleting any empty umbrella projects
    @umbrella_projects = umbrella_project_ids.
      map{ |id| all_project_data[id] }.compact
    if options[:trim_slackers]
      @umbrella_projects = @umbrella_projects.delete_if{ |p| p[:observation_count] == 0 }
    end

    # randomizing subprojects
    @sub_projects = Hash[ sub_project_ids.map{ |umbrella_id,subproject_ids|
      [ umbrella_id, subproject_ids.shuffle.map{ |id| all_project_data[id] }.compact ]
    } ]

    @all_sub_projects = all_project_data.reject{ |k,v| @sub_projects[k] }.values
    @logo_paths = options[:logo_paths] || []

    render "project_slideshow", layout: "basic"
  end

end
