# frozen_string_literal: true

# Bit of a hack to make expose an API for relationships that doesn't use the
# model name Friendship
class RelationshipsController < FriendshipsController
  def create
    if ( existing = current_user.friendships.where( friend_id: approved_create_params[:friend_id] ).first )
      @relationship = existing
      @relationship.assign_attributes( approved_create_params )
    else
      @relationship = current_user.friendships.new( approved_create_params )
    end
    respond_to do | format |
      format.json do
        if @relationship.save
          render json: { relationship: @relationship }
        else
          render status: :unprocessable_entity, json: @relationship.errors
        end
      end
    end
  end

  protected

  def approved_create_params
    params.require( :relationship ).permit(
      :friend_id,
      :following,
      :trust
    )
  end

  def approved_params
    params.require( :relationship ).permit(
      :following,
      :trust
    )
  end

  def load_record( options = {} )
    super( options.merge( klass: Friendship ) )
  end

  def require_owner( options = {} )
    super( options.merge( klass: Friendship ) )
  end
end
