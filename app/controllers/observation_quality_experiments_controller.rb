# frozen_string_literal: true

class ObservationAccuracyExperimentsController < ApplicationController
  def show
    @experiment = ObservationAccuracyExperiment.find( params[:id] )
    keys = ["quality_grade", "continent", "year", "iconic_taxon_name", "taxon_observations_count", "taxon_rank_level"]
    @stats = @experiment.get_top_level_stats
    @data = {}
    keys.each do | key |
      @data[key] = @experiment.get_barplot_data( key )
    end
    render "show"
  end
end
