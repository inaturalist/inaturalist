class LifelistsController < ApplicationController

  before_filter :load_user_by_login, only: [:by_login]

  def by_login
    respond_to do |format|
      format.html do
        render layout: "bootstrap"
      end
      format.csv do
        tmp_path = DynamicLifelist.export( @selected_user )
        if tmp_path.blank?
          render json: { error: t(:internal_server_error) }, status: 500
          return
        end
        response.headers['Content-Disposition'] = "attachment; filename=\"#{File.basename(tmp_path)}\""
        render file: tmp_path
      end
    end
  end

end