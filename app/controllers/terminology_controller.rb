# frozen_string_literal: true

class TerminologyController < ApplicationController
  OTHER_TERMS = %w(
    lexicon
  ).sort.freeze
  ALLOWED_TERMS = ( Observation::ALL_EXPORT_COLUMNS + OTHER_TERMS ).sort

  layout "bootstrap-container"

  def index
    @export_terms = Observation::ALL_EXPORT_COLUMNS.sort
    @other_terms = OTHER_TERMS
  end

  def show
    # If this looks like an observation field, try to redirect to it
    if ( observation_field_name = params[:term][/field:([\w\s]+)/, 1] )
      observation_field = ObservationField.where( "LOWER(name) = ?", observation_field_name.downcase ).first
      return redirect_to( observation_field ) if observation_field
    end

    # Check if term allowed
    @term = params[:term] if ALLOWED_TERMS.include?( params[:term] )
    return render_404 unless @term

    # Redirect to main list
    redirect_to terminology_path( anchor: @term )
  end
end
