# frozen_string_literal: true

class ObservationAccuracyExperimentsController < ApplicationController
  layout "bootstrap"

  def get_more_validators
    experiment_id = params[:experimentId]
    @experiment = ObservationAccuracyExperiment.find( experiment_id )
    @more_validators = get_validator_names( limit: nil, offset: 20 )
    respond_to do | format |
      format.html { render partial: "additional_validators", locals: { validators: @more_validators } }
    end
  end

  def show
    @experiment = ObservationAccuracyExperiment.find( params[:id] )
    keys = ["quality_grade", "continent", "year", "iconic_taxon_name", "taxon_observations_count", "taxon_rank_level"]
    @validators = get_validator_names( limit: 20, offset: 0 )
    @stats = @experiment.get_top_level_stats
    @data = {}
    keys.each do | key |
      @data[key] = @experiment.get_barplot_data( key )
    end
    render "show"
  end
end
