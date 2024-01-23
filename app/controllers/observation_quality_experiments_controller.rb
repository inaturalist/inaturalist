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
    @validators = @experiment.get_validator_names( limit: 20, offset: 0 )
    @tab = params[:tab] || "research_grade_results"
    @stats, @data, @precision_data = get_data_for_tab
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
    [@stats, @data, @precision_data]
  end
end
