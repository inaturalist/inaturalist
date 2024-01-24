# frozen_string_literal: true

class ObservationAccuracyExperimentsController < ApplicationController
  layout "bootstrap"

  def get_more_validators
    experiment_id = params[:id]
    @experiment = ObservationAccuracyExperiment.find( experiment_id )
    @more_validators = @experiment.get_validator_names( limit: nil, offset: 20 )
    respond_to do | format |
      format.html { render partial: "additional_validators", locals: { validators: @more_validators } }
    end
  end

  def show
    @experiment = ObservationAccuracyExperiment.find( params[:id] )
    @explorable = ( @experiment.validator_deadline_date > Time.now ) ||
      ( logged_in? && ( current_user.is_admin? || is_curator_or_site_admin ) )
    @validators = @experiment.get_validator_names( limit: 20, offset: 0 )
    @tab = params[:tab] || "research_grade_results"
    @stats, @data, @precision_data = get_data_for_tab unless @tab == "methods"
    if @tab == "methods"
      @candidate_validators = @experiment.observation_accuracy_validators.count
      @mean_validators_per_sample = @experiment.observation_accuracy_samples.
        map( &:reviewers ).sum / @experiment.observation_accuracy_samples.count
      @mean_validator_count = @experiment.observation_accuracy_samples.includes( :observation_accuracy_validators ).
        average( "observation_accuracy_validators.id" )
      @mean_sample_count = @experiment.observation_accuracy_validators.includes( :observation_accuracy_samples ).
        average( "observation_accuracy_samples.id" )
      grouped_observation_ids = @experiment.observation_accuracy_samples.
        group( :reviewers ).pluck( :reviewers, "ARRAY_AGG( observation_id )" )
      @validators_per_sample = { "0": [], "1": [], "2-5": [], ">5": [] }
      grouped_observation_ids.each do | reviewers, observation_ids |
        case reviewers
        when 0
          @validators_per_sample[:"0"] = observation_ids
        when 1
          @validators_per_sample[:"1"] = observation_ids
        when 2..5
          @validators_per_sample[:"2-5"] += observation_ids
        else
          @validators_per_sample[:">5"] += observation_ids
        end
      end
    end
    render "show"
  end

  private

  def get_data_for_tab
    valid_tabs = %w(research_grade_results verifiable_results all_results methods)
    @tab = "research_grade_results" unless valid_tabs.include?( @tab )
    @stats = @experiment.get_top_level_stats( @tab )
    keys = ["quality_grade", "continent", "year", "iconic_taxon_name", "taxon_observations_count", "taxon_rank_level"]
    keys.delete( "quality_grade" ) if @tab == "research_grade_results"
    @data = keys.each_with_object( {} ) do | key, data |
      data[key] = @experiment.get_barplot_data( key, @tab )
    end
    @precision_data = keys.each_with_object( {} ) do | key, data |
      data[key] = @experiment.get_precision_barplot_data( key, @tab )
    end
    @ylims = {}
    @data.each do | key, sub_data |
      max = sub_data.transform_values {| items | items.sum {| item | item[:altheight] } }.values.max
      @ylims[key.to_sym] = ( max.to_f / 100 ).ceil * 100
    end
    [@stats, @data, @precision_data, @ylims]
  end
end
