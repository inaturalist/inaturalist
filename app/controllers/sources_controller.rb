class SourcesController < ApplicationController
  before_action :authenticate_user!, :except => [:index, :show]
  before_action :load_source, :only => [:show, :edit, :update, :destroy]
  before_action :ensure_can_edit, :only => [:edit, :update, :destroy]

  layout "bootstrap"
  
  def index
    @q = params[:q] || params[:term]
    scope = Source.all
    scope = scope.where(["lower(title) LIKE ?", "%#{@q.downcase}%"]) unless @q.blank?
    @sources = scope.paginate(:page => params[:page])
    respond_to do |format|
      format.html
      format.json do
        @sources = @sources.map do |source|
          source.html = render_to_string(:partial => "chooser.html.haml", :object => source)
          source
        end
        render :json => @sources.to_json(:methods => [:html])
      end
    end
  end
  
  def show
    respond_to do |format|
      format.html
      format.json do
        @source.html = render_to_string(:partial => "chooser.html.haml", :object => @source)
        render :json => @source.to_json(:methods => [:html])
      end
    end
  end
  
  def edit
  end
  
  def update
    @source.update(params[:source])
    respond_to do |format|
      format.html do
        if @source.valid?
          flash[:notice] = "Source saved"
        else
          flash[:error] = "We had trouble saving that source: #{@source.errors.full_messages.to_sentence}"
        end
        redirect_back_or_default(@source)
      end
    end
  end
  
  def new
    @source = Source.new
    respond_to do |format|
      format.html
    end
  end

  def create
    @source = Source.new(params[:source])
    @source.user = current_user
    respond_to do |format|
      format.html do
        if @source.save
          flash[:notice] = "Source created"
          redirect_to @source
        else
          flash[:notice] = "Errors: #{@source.errors.full_messages.to_sentence}"
          render :action => "new"
        end
      end
    end
  end
  
  def destroy
    @source.destroy
    flash[:notice] = "Source destroyed"
    redirect_back_or_default(sources_path)
  end
  
  private
  def load_source
    render_404 unless @source = Source.find_by_id(params[:id])
  end
  
  def ensure_can_edit
    unless @source.editable_by?(current_user)
      flash[:error] = "You don't have permission to do that"
      redirect_to_back_or_default(@source)
    end
  end
end
