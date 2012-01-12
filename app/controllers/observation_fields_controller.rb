class ObservationFieldsController < ApplicationController
  before_filter :login_required
  before_filter :admin_required
  before_filter :load_observation_field, :only => [:show, :edit, :update, :destroy]
  before_filter :owner_or_curator_required, :only => [:edit, :update, :destroy]
  
  # GET /observation_fields
  # GET /observation_fields.xml
  def index
    @q = params[:q] || params[:term]
    scope = ObservationField.scoped({})
    scope = scope.scoped(:conditions => ["lower(name) LIKE ?", "%#{@q.downcase}%"]) unless @q.blank?
    @observation_fields = scope.paginate(:page => params[:page])
    
    respond_to do |format|
      format.html # index.html.erb
      format.json  { render :json => @observation_fields }
    end
  end

  # GET /observation_fields/1
  # GET /observation_fields/1.xml
  def show
    respond_to do |format|
      format.html do
        @observation_field_values = ObservationFieldValue.paginate(:page => params[:page], 
          :include => [:observation],
          :conditions => {:observation_field_id => @observation_field})
        @observations = @observation_field_values.map{|ofv| ofv.observation}
      end
      format.json  { render :json => @observation_field }
    end
  end

  # GET /observation_fields/new
  # GET /observation_fields/new.xml
  def new
    @observation_field = ObservationField.new

    respond_to do |format|
      format.html # new.html.erb
      format.js do
        render :partial => "form"
      end
    end
  end

  # GET /observation_fields/1/edit
  def edit
  end

  # POST /observation_fields
  # POST /observation_fields.xml
  def create
    @observation_field = ObservationField.new(params[:observation_field])
    @observation_field.user = current_user

    respond_to do |format|
      if @observation_field.save
        format.html { redirect_to(@observation_field, :notice => 'ObservationField was successfully created.') }
        format.json  { render :json => @observation_field, :status => :created, :location => @observation_field }
      else
        format.html { render :action => "new" }
        format.json  { render :json => @observation_field.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /observation_fields/1
  # PUT /observation_fields/1.xml
  def update
    respond_to do |format|
      if @observation_field.update_attributes(params[:observation_field])
        format.html { redirect_to(@observation_field, :notice => 'ObservationField was successfully updated.') }
        format.json  { render :json => @observation_field }
      else
        format.html { render :action => "edit" }
        format.json  { render :json => @observation_field.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /observation_fields/1
  # DELETE /observation_fields/1.xml
  def destroy
    @observation_field.destroy

    respond_to do |format|
      format.html { redirect_to(observation_fields_url) }
      format.json  { head :ok }
    end
  end
  
  private
  
  def  load_observation_field
    render_404 unless @observation_field = ObservationField.find_by_id(params[:id].to_i)
  end
  
  def owner_or_curator_required
    unless @observation_field.user_id == current_user.id || current_user.is_curator?
      flash[:error] = "You don't have permission to do that"
      redirect_back_or_default observation_fields_path
    end
  end
end
