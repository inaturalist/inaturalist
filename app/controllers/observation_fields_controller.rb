class ObservationFieldsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_filter :load_observation_field, :only => [:show, :edit, :update, :destroy, :merge, :merge_field]
  before_filter :owner_or_curator_required, :only => [:edit, :update, :destroy, :merge, :merge_field]
  
  # GET /observation_fields
  # GET /observation_fields.xml
  def index
    @q = params[:q] || params[:term]
    scope = ObservationField.all
    scope = scope.where("lower(name) LIKE ?", "%#{@q.downcase}%") unless @q.blank?
    @observation_fields = scope.paginate(:page => params[:page])
    
    respond_to do |format|
      format.html # index.html.erb
      format.json  do
        extra = params[:extra].to_s.split(',')
        opts = if extra.include?('counts')
          {:methods => [:observations_count, :projects_count]}
        else
          {}
        end
        render :json => @observation_fields.as_json(opts)
      end
    end
  end

  # GET /observation_fields/1
  # GET /observation_fields/1.xml
  def show
    respond_to do |format|
      format.html do
        @value = params[:value] || "any"
        scope = ObservationFieldValue.includes(:observation).
          where(:observation_field_id => @observation_field).
          order("observation_field_values.id DESC")
        scope = scope.where("value = ?", @value) unless @value == "any"
        @observation_field_values = scope.page(params[:page])
        @observations = @observation_field_values.map{|ofv| ofv.observation}
        @projects = @observation_field.project_observation_fields.includes(:project).page(1).map(&:project)
      end
      format.json  do
        extra = params[:extra].to_s.split(',')
        opts = if extra.include?('counts')
          {:methods => [:observations_count, :projects_count]}
        else
          {}
        end
        render :json => @observation_field.as_json(opts)
      end
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
        format.json  { render :json => {:errors => @observation_field.errors.full_messages}, :status => :unprocessable_entity }
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
        format.json  { render :json => {:errors => @observation_field.errors.full_messages}, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /observation_fields/1
  # DELETE /observation_fields/1.xml
  def destroy
    if @observation_field.observation_field_values.count > 0
      msg = t(:you_cant_delete_observation_fields_that_people_are_using)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to(observation_fields_url)
        end
        format.json  { render :json => {:error => msg}, :status => :unprocessable_entity }
      end
    else
      @observation_field.destroy
      respond_to do |format|
        format.html { redirect_to(observation_fields_url) }
        format.json  { head :ok }
      end
    end
  end

  def merge
    @reject = @observation_field
    @keeper = ObservationField.find_by_id(params[:with])
    respond_to do |format|
      format.html
    end
  end

  def merge_field
    @keeper = ObservationField.find_by_id(params[:with])
    @reject = @observation_field
    error = if @keeper.blank?
      t(:you_must_choose_an_observation_field)
    elsif @reject.project_observation_fields.exists?
      t(:you_cant_merge_observation_fields_in_use_by_projects)
    end
    if error
      respond_to do |format|
        format.html do
          flash[:error] = error
          redirect_back_or_default @observation_field
        end
      end
      return
    end

    merge = []
    keepers = []
    params.each do |k,v|
      if v.is_a?(Array) && v.size == 2
        merge << k.gsub('keep_', '')
      elsif k =~ /^keep_/ && v == 'reject'
        keepers << k.gsub('keep_', '')
      end
    end

    @keeper.merge(@reject, :merge => merge, :keep => keepers)

    respond_to do |format|
      format.html do
        flash[:notice] = t(:fields_merged)
        redirect_to @keeper
      end
    end
  end
  
  private
  
  def load_observation_field
    render_404 unless @observation_field = ObservationField.find_by_id(params[:id].to_i)
  end
  
  def owner_or_curator_required
    unless @observation_field.editable_by?(current_user)
      flash[:error] = "You don't have permission to do that"
      redirect_back_or_default observation_fields_path
    end
  end
end
