class FlagsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  before_filter :curator_required, :only => [:edit, :update, :destroy]
  before_filter :set_model, :except => [:update, :show, :destroy]
  before_filter :load_flag, :only => [:show, :edit, :destroy, :update]
  
  # put the parameters for the foreign keys here
  FLAG_MODELS = ["Observation","Taxon","Post"]
  FLAG_MODELS_ID = ["observation_id","taxon_id","post_id"]

  def index
    @object = @model.find(params[@param])
    @flags = @object.flags.all(:include => :user, :limit => 500, :order => "id desc")
    @unresolved = @flags.select {|f| not f.resolved }
    @resolved = @flags.select {|f| f.resolved }
  end
  
  def show
    @object = @flag.flagged_object
  end
  
  def new
    @flag = Flag.new(params[:flag])
    @object = @model.find(params[@param])
    @flags = @object.flags.all(:include => :user, :conditions => {:resolved => false})
  end
  
  def create
    create_options = params[:flag]
    create_options[:user_id] = current_user.id
    @object = @model.find_by_id(params[:flag][:flaggable_id])
    unless @object
      flash[:error] = "Can't flag an objec that doesn't exist"
      redirect_to root_path
    end
    
    flag = @object.flags.build(create_options)
    if flag.save
      flash[:notice] = "Your flagging was saved.  Thanks!"
    else
      flash[:error] = "We had a problem saving your flagging."
    end
    redirect_to @object
  end
  
  def update
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
    @flag.destroy
    respond_to do |format|
      format.html { redirect_to(admin_path) }
    end
  end
  
  private
  
  def load_flag
    @flag = Flag.find_by_id(params[:id], :include => [:user, :resolver])
  end
  
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
