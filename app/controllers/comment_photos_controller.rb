# frozen_string_literal: true

# Creates the CommentPhoto join the moment a photo is dropped into a comment
# editor, before the comment itself exists. The row starts unlinked
# (comment_id IS NULL) and Comment#sync_comment_photos links it on submit.
# Same-origin only (the web dropzone posts here directly); comment creation
# itself still goes through the node API untouched.
class CommentPhotosController < ApplicationController
  before_action :doorkeeper_authorize!, only: [:create],
    if: -> { authenticate_with_oauth? }
  before_action :authenticate_user!, unless: -> { authenticated_with_oauth? }

  # Scoped to comment photos only, so it never affects bulk observation uploads.
  MAX_PER_HOUR = 60

  def create
    if recent_comment_photo_count >= MAX_PER_HOUR
      render json: { errors: ["You have uploaded too many photos recently. Please try again later."] },
        status: :too_many_requests
      return
    end

    photo = current_user.photos.find_by( id: params[:photo_id] )
    comment_photo = CommentPhoto.new( photo: photo, user: current_user )
    if photo && comment_photo.save
      render json: comment_photo.as_json, status: :created
    else
      errors = photo ? comment_photo.errors.full_messages : ["No photo specified"]
      render json: { errors: errors }, status: :unprocessable_entity
    end
  end

  private

  def recent_comment_photo_count
    CommentPhoto.where( user_id: current_user.id ).
      where( "created_at > ?", 1.hour.ago ).count
  end
end
