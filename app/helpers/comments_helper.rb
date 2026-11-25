# frozen_string_literal: true

module CommentsHelper
  def visible_comments( parent )
    return parent.comments if is_admin? || is_curator?

    parent.comments.select {| c | !c.flagged? || c.user_id == current_user&.id }
  end

  def comment_action_links( comment )
    return [] unless logged_in?

    hidden = comment.hidden?
    mine = is_me?( comment.user )
    comments_disabled = comment.parent.try( :prefers_no_comments? )
    [
      mine && !hidden && !comments_disabled && link_to( t( :edit ), edit_comment_path( comment ) ),
      !hidden && ( mine || comment.deletable_by?( current_user ) ) && link_to( t( :delete ), comment,
        data: { confirm: t( :are_you_sure_you_want_to_delete_this ) },
        method: :delete,
        id: "delete_comment_#{comment.id}_button" ),
      link_to( t( :flag ), new_flag_path( comment_id: comment ), class: "flaglink" ),
      ( hidden ? comment.unhideable_by?( current_user ) : comment.hideable_by?( current_user ) ) &&
        link_to( t( hidden ? :unhide_content : :hide ), hide_comment_path( comment ) )
    ].select( &:itself )
  end
end
