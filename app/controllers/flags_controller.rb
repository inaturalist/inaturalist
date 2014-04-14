class FlagsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_filter :curator_required, :only => [:edit, :update, :destroy]
  before_filter :set_model, :except => [:update, :show, :destroy]
  before_filter :load_flag, :only => [:show, :edit, :destroy, :update]
  
  # put the parameters for the foreign keys here
  FLAG_MODELS = ["Observation", "Taxon", "Post", "Comment", "Identification", "Message"]
  FLAG_MODELS_ID = ["observation_id","taxon_id","post_id", "comment_id", "identification_id", "message_id"]
  PARTIALS = %w(dialog)

  def index
    @object = @model.find(params[@param])
    @flags = @object.flags.paginate(:page => params[:page],
      :include => [:user, :resolver], :order => "id desc")
    @unresolved = @flags.select {|f| not f.resolved }
    @resolved = @flags.select {|f| f.resolved }
  end
  
  def show
    @object = @flag.flagged_object
  end
  
  def new
    @flag = Flag.new(params[:flag])
    @object = @model.find(params[@param])
    @flag.flaggable ||= @object
    @flag.flag ||= "spam" if @object && !@object.is_a?(Taxon)
    @flags = @object.flags.all(:include => :user, :conditions => {:resolved => false})
    if PARTIALS.include?(params[:partial])
      render :layout => false, :partial => params[:partial]
      return
    end
  end
  
  def create
    create_options = params[:flag]
    create_options[:user_id] = current_user.id
    @object = @model.find_by_id(params[:flag][:flaggable_id])
    unless @object
      flash[:error] = t(:cant_flag_an_object_that_doesnt_exist)
      redirect_to root_path
    end
    
    @flag = @object.flags.build(create_options)
    if @flag.flag == "other" && !params[:flag_explanation].blank?
      @flag.flag = params[:flag_explanation]
    end
    if @flag.save
      flash[:notice] = t(:flag_saved_thanks)
    else
      flash[:error] = t(:we_had_a_problem_flagging_that_item, :flag_error => @flag.errors.full_messages.to_sentence.downcase)
    end
    if @object.is_a?(Comment)
      redirect_to @object.parent
    elsif @object.is_a?(Identification)
      redirect_to @object.observation
    elsif @object.is_a?(Message)
      redirect_to messages_path
    else
      redirect_to @object
    end
  end
  
  def update
    respond_to do |format|
      if @flag.update_attributes(params[:flag])
        flash[:notice] = t(:flag_saved)
      else
        flash[:notice] = t(:we_had_a_problem_flagging_that_item, :flag_error => @flag.errors.full_messages.to_sentence)
      end
      format.html do 
        redirect_back_or_default(@flag)
      end
    end
    
  end
  
  def destroy
    @flag.destroy
    respond_to do |format|
      format.html { redirect_back_or_default(admin_path) }
    end
  end
  
  private
  
  def load_flag
    render_404 unless @flag = Flag.find_by_id(params[:id] || params[:flag_id], :include => [:user, :resolver])
  end
  
  def set_model
    params.each do |key,value|
      if FLAG_MODELS_ID.include? key
        @param = key
        object_name = key.split("_id")[0]
        @model = eval(object_name.camelcase)
        return
      end
    end
    if (@model ||= Object.const_get(params[:flag][:flaggable_type]) rescue nil)
      return
    end
    flash[:notice] = t(:you_cant_flag_that)
    redirect_to observations_path
  end
end
