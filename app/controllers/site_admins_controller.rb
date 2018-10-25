class SiteAdminsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :admin_required

  # POST /site_admins
  # POST /site_admins.json
  def create
    @record = SiteAdmin.new(params[:site_admin])

    respond_to do |format|
      if @record.save
        format.json { render json: @record, status: :created, location: @record }
      else
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /site_admins/1
  # DELETE /site_admins/1.json
  def destroy
    @record = if params[:id]
      SiteAdmin.find( params[:id] )
    elsif params[:site_admin] && params[:site_admin][:user_id] && params[:site_admin][:site_id]
      SiteAdmin.where( params[:site_admin] ).first
    end
    unless @record
      request.format = :json
      return render_404
    end
    @record.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

end
