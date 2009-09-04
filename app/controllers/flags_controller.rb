class FlagsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  before_filter :curator_required, :only => [:edit, :update, :destroy]
  before_filter :set_model, :except => [:update, :show, :destroy]
  
  # put the parameters for the foreign keys here
  FLAG_MODELS = ["Observation","Taxon","Post"]
  FLAG_MODELS_ID = ["observation_id","taxon_id","post_id"]

  def index
    @object = @model.find(params[@param])
    @flags = @object.flags
    @unresolved = @flags.select {|f| not f.resolved }
    @resolved = @flags.select {|f| f.resolved }
  end
  
  def show
    @flag = Flag.find(params[:id])
    @object = @flag.flagged_object
  end
  
  def new
    @flag = Flag.new(params[:flag])
    @object = @model.find(params[@param])
    @flags = @object.flags.select {|f| not f.resolved }
  end
  
  def create
    create_options = params[:flag]
    create_options[:user_id] = current_user.id
    flag = Flag.new(create_options)
    @object = @model.find(params[:flag][:flaggable_id])
    respond_to do |format|
      if  @object.add_flag flag
        flash[:notice] = "Your flagging was saved.  Thanks!"
      else
        flash[:notice] = "We had a problem saving your flagging."
      end
      format.html do
        redirect_to(@object)
      end
    end
  end
  
  def update
    @flag = Flag.find(params[:id])
    @object = @flag.flagged_object
    respond_to do |format|
      if @flag.update_attributes(params[:flag])
        flash[:notice] = "Your flag was saved."
      else
        flash[:notice] = "We had a problem saving your flag."
      end
      format.html do 
        render :action => "show"
      end
    end
    
  end
  
  def destroy
    @flag = Flag.find(params[:id])
    @flag.destroy
    respond_to do |format|
      format.html { redirect_to(admin_path) }
    end
  end
  
  private
  def set_model
    params.each do |key,value|
      if FLAG_MODELS_ID.include? key
        @param = key
        object_name = key.split("_id")[0]
        @model = eval(object_name.capitalize)
        return
      end
    end
    flash[:notice] = "You can't flag that"
    redirect_to observations_path
  end
end
