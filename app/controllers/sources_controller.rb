class SourcesController < ApplicationController
  before_filter :login_required
  
  def index
    @q = params[:q] || params[:term]
    scope = Source.scoped({})
    scope = scope.scoped(:conditions => ["lower(title) LIKE ?", "#{@q.downcase}%"]) unless @q.blank?
    @sources = scope.paginate(:page => params[:page])
    respond_to do |format|
      format.html
      format.json do
        @sources = @sources.map do |source|
          source.html = render_to_string(:partial => "chooser.html.erb", :object => source)
          source
        end
        render :json => @sources.to_json(:methods => [:html])
      end
    end
  end
  
  def show
    @source = Source.find_by_id(params[:id])
    respond_to do |format|
      format.json do
        @source.html = render_to_string(:partial => "chooser.html.erb", :object => @source)
        render :json => @source.to_json(:methods => [:html])
      end
    end
  end
end
