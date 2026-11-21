# frozen_string_literal: true

# Uploads images for posts before the post is saved. Uploads start unclaimed
# (post_id NULL); Post#sync_post_images claims them when a post that uses
# them is saved, and inaturalist:delete_orphaned_post_images deletes the rest.
class PostImagesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_post_image, only: [:update]
  before_action :uploader_required, only: [:update]

  MAX_PER_HOUR = 60

  def create
    if recent_upload_count >= MAX_PER_HOUR
      render json: { errors: [t( :post_image_upload_limit_reached )] }, status: :too_many_requests
      return
    end

    @post_image = PostImage.new( file: params[:file], user: current_user )
    if @post_image.save
      render json: @post_image.upload_json, status: :created
    else
      render json: { errors: @post_image.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Only caption, attribution and alt can change. They're set for the cover;
  # body images keep theirs in the body HTML.
  def update
    if @post_image.update( post_image_params )
      render json: @post_image.upload_json
    else
      render json: { errors: @post_image.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def load_post_image
    render_404 unless ( @post_image = PostImage.find_by_id( params[:id] ) )
  end

  # Uploader only: unlike ApplicationController#require_owner, admins can't
  # edit other people's images
  def uploader_required
    return if @post_image.user_id == current_user.id

    render json: { error: t( :you_dont_have_permission_to_do_that ) }, status: :forbidden
  end

  def post_image_params
    return {} unless params[:post_image].respond_to?( :permit )

    params[:post_image].permit( :caption, :attribution, :alt )
  end

  def recent_upload_count
    PostImage.where( user_id: current_user.id ).where( "created_at > ?", 1.hour.ago ).count
  end
end
