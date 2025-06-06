# frozen_string_literal: true

class EolController < ApplicationController
  before_action :return_here, only: [:options]
  before_action :authenticate_user!

  # Return an HTML fragment containing checkbox inputs for EOL photos.
  # Params:
  #   taxon_id:        a taxon_id
  #   q:        a search param
  def photo_fields
    @photos = []
    @q = if !params[:q].blank?
      params[:q]
    elsif ( taxon_id = params[:taxon_id] )
      @taxon = Taxon.find_by_id( taxon_id )
      @taxon.name
    end

    per_page = params[:limit].to_i
    per_page = 36 if per_page.blank? || per_page.to_i > 36
    page = params[:page].to_i
    page = 1 if page.zero?

    @photos = begin
      EolPhoto.search_eol( @q, page: page, per_page: per_page, eol_page_id: params[:eol_page_id] )
    rescue Timeout::Error
      @timeout = true
      []
    end

    partial = params[:partial].to_s
    partial = "photo_list_form" unless %w(photo_list_form bootstrap_photo_list_form).include?( partial )
    respond_to do | format |
      format.html do
        render partial: "photos/#{partial}", locals: {
          photos: @photos,
          index: params[:index],
          local_photos: false
        }
      end
      format.json do
        if @timeout
          return render json: [], status: :gateway_timeout
        end

        render json: @photos
      end
    end
  end
end
