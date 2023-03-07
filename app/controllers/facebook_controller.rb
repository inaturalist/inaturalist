# frozen_string_literal: true

class FacebookController < ApplicationController
  before_action :return_here, only: [:options]
  before_action :authenticate_user!, except: [:index]

  def index
    response.headers.delete "X-Frame-Options"
    @headless = @footless = true
    return if params[:by].blank?

    @selected_user = User.find_by_id( params[:by] ) || User.find_by_login( params[:by] )
  end

  # Vestigial since we removed importing Facebook photos in 2020. This is just
  # here to notify users that might still have a linked Facebook account. It
  # may not even be necessary anymore
  def photo_fields
    @context = params[:context] || "user"
    if @context == "groups"
      @groups = []
      render partial: "facebook/groups" and return
    end
    if @context == "friends"
      render partial: "facebook/albums"
    else # assume @context == 'user'
      @albums = []
      render partial: "facebook/albums" and return
    end
  end
end
