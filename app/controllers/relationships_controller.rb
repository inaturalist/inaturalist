# Bit of a hack to make expose an API for relationships that doesn't use the
# model name Friendship
class RelationshipsController < FriendshipsController

  protected
  
  def approved_params
    params.require(:relationship).permit(
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
