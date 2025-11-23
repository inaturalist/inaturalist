# frozen_string_literal: true

class IdSummariesFeedbackDashboardController < ApplicationController
  before_action :admin_required

  MAX_LIMIT = 500
  MAX_OFFSET = 50_000
  DEFAULT_LANGUAGE = "en"
  TABS = %w[summaries references voters taxa].freeze

  def index
    @metrics = IdSummaryDqa::PUBLIC_METRICS
    @metric_labels = @metrics.index_with do |metric|
      I18n.t( "id_summary_dqa.public_metrics.#{metric}", default: metric.humanize )
    end
    @reference_metrics = IdSummaryReferenceDqa::PUBLIC_METRICS
    @reference_metric_labels = @reference_metrics.index_with do |metric|
      I18n.t( "id_summary_reference_dqa.public_metrics.#{metric}", default: metric.humanize )
    end
    @language_options = language_select_options

    @active_tab = params[:tab].presence_in( TABS ) || "summaries"

    @filters = {
      run_name: params[:run_name].presence,
      language: language_param,
      active_state: active_state_param,
      user_id: user_id_param,
      user_login: params[:user_login].presence,
      limit: limit_param,
      offset: offset_param,
      voter_feedback_source: voter_feedback_source_param,
      taxa_feedback_source: taxa_feedback_source_param
    }
    @language_form_value = params.key?( :language ) ? params[:language] : @filters[:language]

    summary_scope = apply_common_filters( IdSummaryDqa.joins( id_summary: :taxon_id_summary ) )
    reference_scope = apply_common_filters(
      IdSummaryReferenceDqa.joins( id_summary_reference: { id_summary: :taxon_id_summary } ),
      table_alias: :id_summary_reference_dqas
    )

    if show_summaries?
      @summary_total_votes = summary_scope.count
      @summary_total_summaries = summary_scope.distinct.count( "id_summaries.id" )
      @taxon_feedback = aggregated_feedback_scope( summary_scope )
        .order( Arel.sql( "(#{global_positive_expression}) DESC NULLS LAST" ) )
        .order( Arel.sql( "taxon_id_summaries.updated_at DESC" ) )
        .limit( @filters[:limit] )
        .offset( @filters[:offset] )
        .load
      @taxon_feedback_count = @taxon_feedback.length
    else
      @taxon_feedback = []
      @taxon_feedback_count = 0
      @summary_total_votes = 0
      @summary_total_summaries = 0
    end

    if show_references?
      @reference_total_votes = reference_scope.count
      @reference_total_references = reference_scope.distinct.count( "id_summary_references.id" )
      @reference_feedback = aggregated_reference_feedback_scope( reference_scope )
        .order( Arel.sql( "reference_positive_total DESC NULLS LAST" ) )
        .limit( @filters[:limit] )
        .offset( @filters[:offset] )
        .load
      @reference_feedback_count = @reference_feedback.length
    else
      @reference_feedback = []
      @reference_feedback_count = 0
      @reference_total_votes = 0
      @reference_total_references = 0
    end

    voter_scope, voter_alias = voter_scope_with_alias( summary_scope, reference_scope )
    @voters = aggregated_voters_scope( voter_scope, voter_alias )
      .order( Arel.sql( "total_votes DESC, positive_votes DESC" ) )
      .limit( @filters[:limit] )
      .offset( @filters[:offset] )
      .load

    taxa_scope, taxa_alias, taxa_metrics = taxa_scope_with_alias_and_metrics( summary_scope, reference_scope )
    @taxa_feedback = aggregated_taxa_scope( taxa_scope, taxa_alias, taxa_metrics )
      .order( Arel.sql( "positive_total DESC NULLS LAST" ) )
      .limit( @filters[:limit] )
      .offset( @filters[:offset] )
      .load
    @taxa_metrics = taxa_metrics
    @taxa_metric_labels = taxa_metrics.index_with do |metric|
      if @filters[:taxa_feedback_source] == "reference"
        @reference_metric_labels[metric]
      else
        @metric_labels[metric]
      end
    end.compact
  end

  private

  def aggregated_feedback_scope( scope )
    select_columns = [
      "id_summaries.id AS id_summary_id",
      "id_summaries.visual_key_group",
      "id_summaries.summary AS id_summary_text",
      "id_summaries.score AS id_summary_score",
      "id_summaries.created_at AS id_summary_created_at",
      "id_summaries.updated_at AS id_summary_updated_at",
      "taxon_id_summaries.id AS taxon_summary_id",
      "taxon_id_summaries.taxon_id",
      "taxon_id_summaries.taxon_name",
      "taxon_id_summaries.taxon_common_name",
      "taxon_id_summaries.run_name",
      "taxon_id_summaries.language",
      "taxon_id_summaries.active",
      "taxon_id_summaries.run_generated_at",
      "taxon_id_summaries.updated_at",
      "COUNT(*) FILTER (WHERE id_summary_dqas.agree = TRUE) AS positive_total",
      "COUNT(*) FILTER (WHERE id_summary_dqas.agree = FALSE) AS negative_total"
    ]

    @metrics.each do |metric|
      select_columns << <<~SQL.squish
        COUNT(*) FILTER
          (WHERE id_summary_dqas.metric = '#{metric}' AND id_summary_dqas.agree = TRUE)
        AS #{metric}_positive
      SQL
      select_columns << <<~SQL.squish
        COUNT(*) FILTER
          (WHERE id_summary_dqas.metric = '#{metric}' AND id_summary_dqas.agree = FALSE)
        AS #{metric}_negative
      SQL
    end

    group_columns = [
      "id_summaries.id",
      "id_summaries.visual_key_group",
      "id_summaries.summary",
      "id_summaries.score",
      "id_summaries.created_at",
      "id_summaries.updated_at",
      "taxon_id_summaries.id",
      "taxon_id_summaries.taxon_id",
      "taxon_id_summaries.taxon_name",
      "taxon_id_summaries.taxon_common_name",
      "taxon_id_summaries.run_name",
      "taxon_id_summaries.language",
      "taxon_id_summaries.active",
      "taxon_id_summaries.run_generated_at",
      "taxon_id_summaries.updated_at"
    ]

    scope.select( select_columns ).group( group_columns )
  end

  def aggregated_voters_scope( scope, table_alias )
    alias_name = table_alias.to_s
    scope.where.not( table_alias => { user_id: nil } )
      .joins( :user )
      .select( <<~SQL.squish )
        users.id AS user_id,
        users.login AS user_login,
        COUNT(*) AS total_votes,
        SUM(CASE WHEN #{alias_name}.agree = TRUE THEN 1 ELSE 0 END) AS positive_votes,
        SUM(CASE WHEN #{alias_name}.agree = FALSE THEN 1 ELSE 0 END) AS negative_votes
      SQL
      .group( "users.id", "users.login" )
  end

  def aggregated_taxa_scope( scope, table_alias, metrics )
    alias_name = table_alias.to_s
    select_columns = [
      "taxon_id_summaries.id AS taxon_summary_id",
      "taxon_id_summaries.taxon_id AS taxon_id",
      "taxon_id_summaries.taxon_name AS taxon_name",
      "taxon_id_summaries.taxon_common_name AS taxon_common_name",
      "taxon_id_summaries.run_name AS run_name",
      "taxon_id_summaries.language AS language",
      "taxon_id_summaries.active AS active",
      "COUNT(DISTINCT id_summaries.id) AS id_summaries_count",
      "COUNT(*) FILTER (WHERE #{alias_name}.agree = TRUE) AS positive_total",
      "COUNT(*) FILTER (WHERE #{alias_name}.agree = FALSE) AS negative_total"
    ]
    metrics.each do |metric|
      select_columns << <<~SQL.squish
        COUNT(*) FILTER
          (WHERE #{alias_name}.metric = '#{metric}' AND #{alias_name}.agree = TRUE)
        AS #{metric}_positive
      SQL
      select_columns << <<~SQL.squish
        COUNT(*) FILTER
          (WHERE #{alias_name}.metric = '#{metric}' AND #{alias_name}.agree = FALSE)
        AS #{metric}_negative
      SQL
    end
    scope.select( select_columns )
      .group(
        "taxon_id_summaries.id",
        "taxon_id_summaries.taxon_id",
        "taxon_id_summaries.taxon_name",
        "taxon_id_summaries.taxon_common_name",
        "taxon_id_summaries.run_name",
        "taxon_id_summaries.language",
        "taxon_id_summaries.active"
      )
  end

  def aggregated_reference_feedback_scope( scope )
    select_columns = [
      "id_summary_references.id AS reference_id",
      "id_summary_references.reference_source",
      "id_summary_references.reference_uuid",
      "id_summary_references.reference_date",
      "id_summary_references.reference_content",
      "id_summary_references.user_id AS reference_user_id",
      "id_summary_references.user_login AS reference_user_login",
      "id_summaries.id AS reference_summary_id",
      "taxon_id_summaries.id AS taxon_summary_id",
      "taxon_id_summaries.taxon_id",
      "taxon_id_summaries.taxon_name",
      "taxon_id_summaries.taxon_common_name",
      "taxon_id_summaries.run_name",
      "taxon_id_summaries.language",
      "taxon_id_summaries.active",
      "COUNT(*) FILTER (WHERE id_summary_reference_dqas.agree = TRUE) AS reference_positive_total",
      "COUNT(*) FILTER (WHERE id_summary_reference_dqas.agree = FALSE) AS reference_negative_total"
    ]

    @reference_metrics.each do |metric|
      select_columns << <<~SQL.squish
        COUNT(*) FILTER
          (WHERE id_summary_reference_dqas.metric = '#{metric}' AND id_summary_reference_dqas.agree = TRUE)
        AS reference_#{metric}_positive
      SQL
      select_columns << <<~SQL.squish
        COUNT(*) FILTER
          (WHERE id_summary_reference_dqas.metric = '#{metric}' AND id_summary_reference_dqas.agree = FALSE)
        AS reference_#{metric}_negative
      SQL
    end

    group_columns = [
      "id_summary_references.id",
      "id_summary_references.reference_source",
      "id_summary_references.reference_uuid",
      "id_summary_references.reference_date",
      "id_summary_references.reference_content",
      "id_summary_references.user_id",
      "id_summary_references.user_login",
      "id_summaries.id",
      "taxon_id_summaries.id",
      "taxon_id_summaries.taxon_id",
      "taxon_id_summaries.taxon_name",
      "taxon_id_summaries.taxon_common_name",
      "taxon_id_summaries.run_name",
      "taxon_id_summaries.language",
      "taxon_id_summaries.active"
    ]

    scope.select( select_columns ).group( group_columns )
  end

  def voter_scope_with_alias( summary_scope, reference_scope )
    if @filters[:voter_feedback_source] == "reference"
      [reference_scope, :id_summary_reference_dqas]
    else
      [summary_scope, :id_summary_dqas]
    end
  end

  def taxa_scope_with_alias_and_metrics( summary_scope, reference_scope )
    if @filters[:taxa_feedback_source] == "reference"
      [reference_scope, :id_summary_reference_dqas, @reference_metrics]
    else
      [summary_scope, :id_summary_dqas, @metrics]
    end
  end

  def apply_common_filters( scope, table_alias: :id_summary_dqas )
    scope = scope.where( "taxon_id_summaries.run_name ILIKE ?", "%#{@filters[:run_name]}%" ) if @filters[:run_name]
    scope = scope.where( taxon_id_summaries: { language: @filters[:language] } ) if @filters[:language]
    scope = case @filters[:active_state]
            when "active"
              scope.where( taxon_id_summaries: { active: true } )
            when "inactive"
              scope.where( taxon_id_summaries: { active: false } )
            else
              scope
            end
    scope = scope.where( table_alias => { user_id: @filters[:user_id] } ) if @filters[:user_id]
    if @filters[:user_login]
      scope = scope.joins( :user )
      scope = scope.where( "users.login ILIKE ?", "%#{@filters[:user_login]}%" )
    end
    scope
  end

  def global_positive_expression
    "COUNT(*) FILTER (WHERE id_summary_dqas.agree = TRUE)"
  end

  def language_param
    if params.key?( :language )
      value = params[:language].to_s.strip
      return nil if value.blank?

      return value
    end

    DEFAULT_LANGUAGE
  end

  def language_select_options
    languages = TaxonIdSummary.distinct.order( :language ).pluck( :language ).compact
    languages = (languages + [DEFAULT_LANGUAGE]).compact.uniq
    [["Any language", ""]] + languages.map do |lang|
      [lang.presence || "—", lang]
    end
  end

  def user_id_param
    value = params[:user_id].to_i
    return nil if value <= 0

    value
  end

  def limit_param
    limit = params[:limit].to_i
    limit = 100 if limit <= 0
    [limit, MAX_LIMIT].min
  end

  def offset_param
    offset = params[:offset].to_i
    offset = 0 if offset.negative?
    [offset, MAX_OFFSET].min
  end

  def active_state_param
    value = params[:active_state]
    return "active" if value.blank? || value == "active"
    return "inactive" if value == "inactive"
    return "all" if value == "all"

    "active"
  end

  def voter_feedback_source_param
    return "reference" if params[:voter_feedback_source] == "reference"

    "summary"
  end

  def taxa_feedback_source_param
    return "reference" if params[:taxa_feedback_source] == "reference"

    "summary"
  end

  def show_summaries?
    @active_tab == "summaries"
  end

  def show_references?
    @active_tab == "references"
  end
end
