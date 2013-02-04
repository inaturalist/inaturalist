class FlowTasksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin_required, :only => [:index]
  before_filter :load_flow_task, :only => [:show, :destroy, :run]
  before_filter :require_owner, :only => [:destroy, :run]
  
  def index
    @flow_tasks = FlowTask.order("id desc").paginate(:page => params[:page])
  end
  
  def show
  end
  
  def new
    klass = params[:type].camlize.constantize rescue FlowTask
    @flow_task = klass.new
  end
  
  def create
    class_name = params.keys.detect{|k| k =~ /flow_task/}
    klass = class_name.camelize.constantize rescue FlowTask
    @flow_task = klass.new(params[class_name])
    @flow_task.user = current_user
    if @flow_task.save
      redirect_to run_flow_task_path(@flow_task)
    else
      flash[:error] = "Failed to save task: " + @flow_task.errors.full_messages.to_sentence
      redirect_back_or_default('/')
    end
  end
  
  def run
    delayed_progress(request.path) do
      @job = Delayed::Job.enqueue(@flow_task)
    end
  end
  
  def destroy
    @flow_task.destroy
    flash[:notice] = "Flow task destroyed"
    redirect_to flow_tasks_path
  end
  
  private
  
  def load_flow_task
    return true if @flow_task = FlowTask.find_by_id(params[:id])
    flash[:error] = "That task doesn't exist"
    redirect_to flow_tasks_path
    false
  end

  def require_owner
    unless logged_in? && current_user.id == @flow_task.user_id
      flash[:error] = "You don't have permission to do that"
      return redirect_to "/"
    end
  end
  
  # Encapsulates common pattern for actions that start a bg task get called 
  # repeatedly to check progress
  # Key is required, and a block that assigns a new Delayed::Job to @job
  def delayed_progress(key)
    @tries = params[:tries].to_i
    if @tries > 20
      @status = @error
      @error_msg = "This is taking forever.  Please try again later."
      return
    elsif @tries > 0
      @job_id = Rails.cache.read(key)
      @job = Delayed::Job.find_by_id(@job_id)
    end
    if @job_id
      if @job && @job.last_error
        @status = "error"
        @error_msg = @job.last_error
      elsif @job
        @status = "working"
      else
        @status = "done"
        Rails.cache.delete(key)
      end
    else
      @status = "start"
      yield
      Rails.logger.debug "[DEBUG] writing key: #{key} for job id: #{@job.id}"
      Rails.cache.write(key, @job.id)
    end
  end
  
end
