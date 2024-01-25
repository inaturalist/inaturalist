# frozen_string_literal: true

class ObservationAccuracyExperimentsController < ApplicationController
  before_action :load_experiment, only: [:show, :get_more_validators]

  layout "bootstrap"

  def get_more_validators
    @more_validators = @experiment.get_validator_names( limit: nil, offset: 20 )
    respond_to do | format |
      format.html { render partial: "additional_validators", locals: { validators: @more_validators } }
    end
  end

  def show
    @explorable = ( @experiment.validator_deadline_date < Time.now ) ||
      ( logged_in? && ( current_user.is_admin? || is_curator_or_site_admin ) )

    @validators = @experiment.get_validator_names( limit: 20, offset: 0 )
    @tab = params[:tab] || "research_grade_results"
    if @tab == "methods"
      @candidate_validators, @mean_validator_count, @mean_sample_count = @experiment.get_assignment_methods
      @mean_validators_per_sample, @validators_per_sample, @validators_per_sample_ylim = @experiment.get_val_methods
    else
      @stats, @data, @precision_data = @experiment.get_results_data
    end
    render "show"
  end

  private

  def load_experiment
    render_404 unless ( @experiment = ObservationAccuracyExperiment.find_by_id( params[:id] ) )
  end
end
