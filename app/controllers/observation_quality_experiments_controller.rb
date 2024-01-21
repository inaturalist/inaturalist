# frozen_string_literal: true

class ObservationAccuracyExperimentsController < ApplicationController
  def show
    @experiment = ObservationAccuracyExperiment.find( params[:id] )
    keys = ["continent", "quality_grade", "year", "iconic_taxon_name"]
    @data = {}
    keys.each do | key |
      @data[key] = @experiment.get_barplot_data( key )
    end
    render "show"
  end
end
