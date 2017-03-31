class ErrorsController < ApplicationController
  def error_404
    respond_to do |format|
      format.html { render status: 404, layout: "application" }
      format.json { render json: { error: t(:not_found) }, status: 404 }
      format.xml { render xml: { error: t(:not_found) }, status: 404 }
    end
  end

  def error_422
    respond_to do |format|
      format.html { render :error_404, status: 422, layout: "application" }
      format.json { render json: { error: t(:unprocessable) }, status: 422 }
      format.xml { render xml: { error: t(:unprocessable) }, status: 422 }
    end
  end

  def error_500
    respond_to do |format|
      format.html { render status: 500, layout: "application" }
      format.json { render json: { error: t(:internal_server_error) }, status: 500 }
      format.xml { render xml: { error: t(:internal_server_error) }, status: 500 }
    end
  end
end
