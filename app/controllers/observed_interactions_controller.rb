# frozen_string_literal: true

class ObservedInteractionsController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required

  before_action :load_observation, only: [:index, :new]
  after_action :return_here, only: [:new]

  layout "bootstrap-container"

  def index
    @observed_interactions = @observation.observed_interactions
    respond_to do | format |
      format.html
    end
  end

  def new
    @subject_observation = @observation || Observation.find_by_id( params[:subject_observation_id] )
    render_404 unless @subject_observation

    @observed_interaction = ObservedInteraction.new(
      subject_observation: @subject_observation
    )
    @controlled_attribute = ControlledTerm.first_term_by_label( "Interaction" )
    @controlled_values = @controlled_attribute.values
    @observed_interaction.annotations.build(
      controlled_attribute: @controlled_attribute,
      controlled_value: @controlled_values.first,
      user: current_user
    )
    @object_candidates = Observation.
      by( @subject_observation.user ).
      on( @subject_observation.observed_on ).
      where( "observations.id != ?", @subject_observation )
    respond_to do | format |
      format.html
    end
  end

  def create
    params[:observed_interaction][:annotations_attributes].each do | idx, _anno |
      params[:observed_interaction][:annotations_attributes][idx][:user_id] = current_user.id
    end
    @observed_interaction = ObservedInteraction.new( params[:observed_interaction] )
    if @observed_interaction.save
      return redirect_to observation_interactions_path( @observed_interaction.subject_observation )
    end

    flash[:error] = @observed_interaction.errors.full_messages.to_sentence
    redirect_back_or_default @observed_interaction.subject_observation
  end

  private

  def load_observation
    @observation = load_record( klass: "Observation", param: :observation_id )
  end
end
