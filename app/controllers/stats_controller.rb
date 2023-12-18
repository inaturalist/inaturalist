# frozen_string_literal: true

class StatsController < ApplicationController
  before_action :set_time_zone_to_utc
  before_action :load_params, except: [:year, :generate_year]
  before_action :doorkeeper_authorize!,
    only: [:generate_year],
    if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!,
    only: [:cnc2017_taxa, :cnc2017_stats, :generate_year],
    unless: -> { authenticated_with_oauth? }
  before_action :allow_external_iframes, only: [:wed_bioblitz]

  caches_action :summary, expires_in: 1.day
  caches_action :nps_bioblitz, expires_in: 5.minutes
  caches_action :cnc2016, expires_in: 5.minutes
  caches_action :cnc2017, expires_in: 5.minutes

  def index
    respond_to do | format |
      format.json do
        fetch_statistics
        render json: @stats, except: :id, callback: params[:callback]
      end
      format.html do
        if params[:start_date].nil?
          @start_date = @end_date - 1.year
        end
        fetch_statistics
        render layout: "bootstrap"
      end
    end
  end

  def summary
    params = { verifiable: true, per_page: 1 }
    params[:place_id] = @site.place_id if @site.place_id
    observations = INatAPIService.observations( params )
    observers = INatAPIService.observations_observers( params )
    species_counts = INatAPIService.observations_species_counts( params )
    user_count_scope = User.where( "suspended_at IS NULL" )
    if @site && @site != Site.default
      user_count_scope = user_count_scope.where( site_id: @site.id )
    end
    @stats = {
      total_users: user_count_scope.count,
      total_leaf_taxa: species_counts&.total_results || 0,
      total_observations: observations&.total_results || 0,
      total_observed_taxa: species_counts&.total_results || 0,
      total_observers: observers&.total_results || 0,
      updated_at: Time.now
    }
    respond_to do | format |
      format.json { render json: @stats }
    end
  end

  def year
    @year = params[:year].to_i
    if @year > Date.today.year || @year < 1950
      return render_404
    end

    @display_user = User.find_by_login( params[:login] )
    if !params[:login].blank? && !@display_user
      return render_404
    end

    if @display_user && !current_user && !@display_user.locale.blank?
      set_i18n_locale_from_locale_string( @display_user.locale, I18n.locale )
    end
    @year_statistic = if @display_user
      YearStatistic.where( "user_id = ? AND year = ?", @display_user, @year ).first
    elsif Site.default.try( :id ) == @site.id
      YearStatistic.where( "user_id IS NULL and site_id IS NULL and year = ?", @year ).first
    else
      YearStatistic.where( site_id: @site, year: @year ).where( "user_id IS NULL" ).first
    end

    # Embargo current year's global and site YIRs until December 1, except for staff
    if !@display_user &&
        !current_user&.is_admin? &&
        Date.today.year == @year &&
        Date.today < Date.parse( "#{@year}-12-01" )
      @year_statistic = nil
    end
    @headless = @footless = true
    @shareable_image_url = if shareable = @year_statistic&.shareable_image_for_locale( I18n.locale )
      shareable.url
    elsif @display_user&.icon?
      @display_user.icon.url( :large )
    elsif @site.shareable_image?
      @site.shareable_image.url
    end
    respond_to do | format |
      format.html do
        @responsive = true
        render layout: "bootstrap"
      end
      format.json do
        if @year_statistic.blank?
          render_404
          return
        end
        render json: @year_statistic.data
      end
    end
  end

  def your_year
    @year = params[:year].to_i
    if @year > Date.today.year || @year < 1950
      return render_404
    end

    if current_user
      redirect_to user_year_stats_path( login: current_user.login, year: @year )
    else
      redirect_to login_path( return_to: your_year_stats_path( year: @year ) )
    end
  end

  def generate_year
    @year = params[:year].to_i
    if ( @year > Date.today.year ) || ( @year < 1950 )
      return render_404
    end

    delayed_progress( "stats/generate_year?user_id=#{current_user.id}&year=#{@year}" ) do
      @job = YearStatistic.delay(
        priority: USER_PRIORITY,
        unique_hash: "YearStatistic::generate_for_user_year::#{current_user.id}::#{@year}"
      ).generate_for_user_year( current_user.id, @year )
    end
    respond_to do | format |
      format.json do
        status = case @status
        when "done" then :ok
        when "error" then :unprocessable_entity
        else
          202
        end
        render json: { status: status }, status: status
      end
    end
  end

  def nps_bioblitz
    @overall_id = 6810
    umbrella_project_ids = [6810, 7109, 7110, 7107, 6790]
    sub_project_ids = {
      6810 => [],
      7109 => [6818, 6846, 6864, 7026, 6832, 7069, 6859],
      7110 => [6835, 6833, 6840, 7298, 6819, 7299, 6815,
               6814, 7025, 7281, 6816, 7302, 7301, 6822],
      7107 => [6824, 6465, 6478],
      6790 => [6850, 6851, 7167, 6852, 7168, 7169]
    }
    project_slideshow_data( @overall_id, {
      umbrella_project_ids: umbrella_project_ids,
      sub_project_ids: sub_project_ids,
      trim_slackers: true,
      group: Project::NPS_BIOBLITZ_GROUP_NAME,
      title: "NPS Servicewide",
      logo_paths: ["/logo-nps.svg", "/logo-natgeo.svg"]
    } ) do | all_project_data |
      # hard-coding umbrella project places
      all_project_data[6810][:place_id] = 0 if all_project_data[6810]
      all_project_data[7109][:place_id] = 46 if all_project_data[7109]
      all_project_data[7110][:place_id] = 5 if all_project_data[7110]
      all_project_data[7107][:place_id] = 51_727 if all_project_data[7107]
      all_project_data[6790][:place_id] = 43 if all_project_data[6790]
      all_project_data.each do | project_id, project |
        all_project_data[project_id][:title] = project[:title].sub( "2016 National Parks BioBlitz - ", "" )
      end
    end
  end

  def canada_150
    project_slideshow_data( 12_849,
      umbrella_project_ids: [12_849],
      sub_project_ids: {
        12_849 => [
          16_484, 13_474, 14_980, 15_583, 14_782, 14_342, 11_863, 12_646, 12_281, 11_396, 11_693, 10_595, 12_189,
          12_192, 12_743, 12_511, 12_872, 12_748, 11_440, 12_806, 13_124, 12_210, 13_176, 12_024, 13_377, 13_376,
          13_375, 13_374, 12_597, 12_166, 11_451
        ]
      },
      title: "Bioblitz Canada 150" ) do | all_project_data |
      all_project_data[12_849][:place_id] = 6712 if all_project_data[12_849]
    end
  end

  def parks_canada_2017
    project_slideshow_data( 12_851,
      umbrella_project_ids: [12_851],
      sub_project_ids: {
        12_851 => [
          11_728, 11_360, 12_038, 11_487, 12_085, 12_719, 12_720, 11_348, 12_637, 12_231, 13_322, 13_179, 12_315,
          12_799, 13_324, 13_091, 13_215, 13_327, 12_956, 11_337, 12_034, 12_510
        ]
      },
      title: "Parks Canada Bioblitz 2017" ) do | all_project_data |
      all_project_data[12_851][:place_id] = 6712 if all_project_data[12_851]
    end
  end

  def cnc2017
    project_slideshow_data( 11_753,
      umbrella_project_ids: [11_753],
      sub_project_ids: {
        11_753 => [10_931, 11_013, 11_053, 11_126, 10_768, 10_769, 10_752, 10_764,
                   11_047, 11_110, 10_788, 10_695, 10_945, 10_917, 10_763, 11_042]
      },
      title: "City Nature Challenge 2017" ) do | all_project_data |
      all_project_data[11_753][:place_id] = 0 if all_project_data[11_753]
      all_project_data.each do | project_id, project |
        all_project_data[project_id][:title] = project[:title].sub( "City Nature Challenge 2017: ", "" )
      end
    end
  end

  def cnc2017_stats
    project_ids = [
      10_931, 11_013, 11_053, 11_126, 10_768, 10_769, 10_752, 10_764, 11_047, 11_110, 10_788, 10_695, 10_945, 10_917,
      10_763, 11_042
    ]
    # project_ids = [1,2,3,4]
    project_id = params[:project_id] if project_ids.include?( params[:project_id].to_i )
    project_id ||= 11_753
    @projects = Project.where( id: project_ids )
    @project = Project.find( project_id )

    # prepare the data needed for the slideshow
    @data = []
    @projects.each do | p |
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
      species_count = species_count_response&.total_results || 0
      observations_count_response = INatAPIService.observations( node_params )
      observations_count =  observations_count_response&.total_results || 0
      identifiers_count_response = INatAPIService.get( "/observations/identifiers", node_params )
      identifiers_count = identifiers_count_response&.total_results || 0
      observers_count_response = INatAPIService.get( "/observations/observers", node_params )
      observers_count = observers_count_response&.total_results || 0

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
    unique_taxon_ids = Observation.elastic_taxon_leaf_counts( in_project_elastic_params ).map do | taxon_id, count |
      count == 1 ? taxon_id : nil
    end.compact.uniq
    @unique_contributors = User.
      select( "users.*, count(*) AS unique_count, array_agg(observations.taxon_id) AS taxon_ids" ).
      joins( observations: :project_observations ).
      where( "project_observations.project_id = ?", @project ).
      where( "observations.taxon_id IN (?)", unique_taxon_ids ).
      group( "users.id" ).
      order( Arel.sql( "count(*) DESC" ) ).
      limit( 100 )
    case params[:quality]
    when "research"
      @unique_contributors = @unique_contributors.where( "observations.quality_grade = 'research'" )
    when "verifiable"
      @unique_contributors = @unique_contributors.where( "observations.quality_grade IN ('research', 'needs_id')" )
    end

    @rank_counts = Observation.
      query( projects: project_ids ).
      joins( :projects ).
      joins( "LEFT OUTER JOIN taxa ON taxa.id = observations.taxon_id" ).
      select( "projects.slug, taxa.rank, count(*)" ).
      group( "projects.slug, taxa.rank" )
    case params[:quality]
    when "research"
      @rank_counts = @rank_counts.where( quality_grade: "research" )
    when "verifiable"
      @rank_counts = @rank_counts.where( "quality_grade IN ('research', 'needs_id')" )
    end
    @rank_counts = @rank_counts.group_by( &:slug )

    respond_to do | format |
      format.html { render layout: "bootstrap" }
    end
  end

  def cnc2016
    project_slideshow_data( 11_765,
      umbrella_project_ids: [11_765],
      sub_project_ids: {
        11_765 => [6345, 6365]
      },
      title: "City Nature Challenge 2016" ) do | all_project_data |
      all_project_data[11_765][:place_id] = 14 if all_project_data[11_765]
    end
  end

  def wed_bioblitz
    render layout: "basic"
  end

  private

  def set_time_zone_to_utc
    Time.zone = "UTC"
  end

  def load_params
    @end_date = begin
      Time.zone.parse( params[:end_date] ).beginning_of_day
    rescue StandardError
      Time.now
    end
    @start_date = begin
      Time.zone.parse( params[:start_date] ).beginning_of_day
    rescue StandardError
      1.day.ago
    end
    @start_date = Time.zone.now if @start_date > Time.zone.now
    @end_date = Time.zone.now if @end_date > Time.zone.now
    return unless SiteStatistic.first_stat && @start_date < SiteStatistic.first_stat.created_at

    @start_date = SiteStatistic.first_stat.created_at
  end

  def fetch_statistics
    @stats = SiteStatistic.where( created_at: @start_date..@end_date ).order( "created_at desc" )
    return if @stats.any?

    @stats = [SiteStatistic.order( "created_at asc" ).last]
  end

  def project_slideshow_data( overall_project_id, options = {} )
    umbrella_project_ids = options[:umbrella_project_ids] || []
    sub_project_ids = options[:sub_project_ids] || {}
    @overall_id = overall_project_id
    all_project_ids = (
      sub_project_ids.map {| _k, v | v }.flatten +
      sub_project_ids.keys +
      umbrella_project_ids +
      [overall_project_id]
    ).flatten.uniq

    projs = Project.select( "projects.*, count(po.observation_id)" ).
      joins( "LEFT JOIN project_observations po ON (projects.id=po.project_id)" ).
      group( :id ).
      order( Arel.sql( "count(po.observation_id) desc" ) )
    projs = if options[:group]
      projs.where( "projects.group = ? OR projects.id = ? OR projects.id IN (?)", options[:group], params[:project_id],
        all_project_ids )
    else
      projs.where( "projects.id = ? OR projects.id IN (?)", params[:project_id], all_project_ids )
    end

    # prepare the data needed for the slideshow
    begin
      all_project_data = projs.map do | p |
        [p.id,
         {
           id: p.id,
           title: p.title,
           slug: p.slug,
           start_time: p.start_time,
           end_time: p.end_time,
           place_id: p.rule_place.try( :id ),
           observation_count: p.count,
           in_progress: p.event_in_progress?,
           species_count: p.node_api_species_count || 0
         }]
      end.to_h
    rescue StandardError => e
      Rails.logger.debug "[DEBUG] error loading project data: #{e}"
      sleep( 2 )
      return redirect_to :nps_bioblitz_stats
    end

    if block_given?
      yield all_project_data
    end

    # setting the number of slides to show per umbrella project
    umbrella_project_ids.each do | id |
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
      map {| id | all_project_data[id] }.compact
    if options[:trim_slackers]
      @umbrella_projects = @umbrella_projects.delete_if {| p | ( p[:observation_count] ).zero? }
    end

    # randomizing subprojects
    @sub_projects = sub_project_ids.transform_values do | subproject_ids |
      subproject_ids.shuffle.map {| id | all_project_data[id] }.compact
    end

    @all_sub_projects = all_project_data.reject {| k, _v | @sub_projects[k] }.values
    @logo_paths = options[:logo_paths] || []

    render "project_slideshow", layout: "basic"
  end
end
