# frozen_string_literal: true

class AdditionalObserversController < ApplicationController
  before_action :doorkeeper_authorize!, if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!, unless: -> { authenticated_with_oauth? }
  before_action :load_observation
  before_action :require_observation_owner

  def create
    user = User.find_by_id( params[:user_id] ) || User.find_by_login( params[:user_id] )
    unless user
      return render status: :unprocessable_entity, json: {
        errors: [I18n.t( "activerecord.errors.messages.required", default: "User can't be blank" )]
      }
    end

    additional_observer = @observation.additional_observers.build(
      user: user, added_by_user: current_user
    )
    if additional_observer.save
      render json: additional_observer_json( additional_observer )
    else
      render status: :unprocessable_entity, json: {
        errors: additional_observer.errors.full_messages
      }
    end
  end

  def destroy
    if ( additional_observer = @observation.additional_observers.where( user_id: params[:user_id] ).first )
      additional_observer.destroy
    end
    head :ok
  end

  private

  def additional_observer_json( additional_observer )
    {
      id: additional_observer.id,
      observation_id: additional_observer.observation_id,
      user_id: additional_observer.user_id,
      added_by_user_id: additional_observer.added_by_user_id,
      user: {
        id: additional_observer.user.id,
        login: additional_observer.user.login,
        name: additional_observer.user.name,
        icon_url: additional_observer.user.user_icon_url
      }
    }
  end

  def load_observation
    return true if ( @observation = Observation.find_by_id( params[:observation_id] ) )

    render status: :not_found, json: { error: t( :that_observation_doesnt_exist ) }
    false
  end

  def require_observation_owner
    return true if logged_in? && ( current_user.id == @observation.user_id || current_user.is_admin? )

    render status: :forbidden, json: { error: t( :you_dont_have_permission_to_do_that ) }
    false
  end
end
