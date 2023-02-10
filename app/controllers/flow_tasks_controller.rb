class FlowTasksController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required, :only => [:index]
  before_action :load_flow_task, :only => [:show, :destroy, :run]
  before_action :require_owner, :only => [:destroy, :run, :show]
  
  def index
    @flow_tasks = FlowTask.order("id desc").paginate(:page => params[:page])
  end
  
  def show
    respond_to do |format|
      format.html
      format.json do
        render :json => @flow_task.as_json(
          :include => {
            :inputs => {:methods => [:file_url]}, 
            :outputs => {:methods => [:file_url]}
          }
        )
      end
    end
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

    respond_to do |format|
      if @flow_task.save
        format.html do
          redirect_to run_flow_task_path(@flow_task)
        end
        format.json { render :json => @flow_task }
      else
        msg = I18n.t(:failed_to_save_record_with_errors, errors: @flow_task.errors.full_messages.to_sentence )
        format.html do
          flash[:error] = msg
          redirect_back_or_default('/')
        end
        format.json do
          render :json => {:error => msg}, :status => :unprocessable_entity
        end
      end
    end
  end
  
  def run
    delayed_progress(request.path) do
      opts = @flow_task.enqueue_options if @flow_task.respond_to?(:enqueue_options)
      opts ||= {}
      opts[:unique_hash] ||= {'FlowTask': @flow_task.id}
      # set a small default delay in FlowTask processing to avoid effects of replication lag
      opts[:run_at] ||= 5.seconds.from_now
      @job = Delayed::Job.enqueue(@flow_task, opts)
    end
    respond_to do |format|
      format.html
      format.json do
        status = case @status
        when "done" then :ok
        when "error" then :unprocessable_entity
        else
          202
        end
        render :json => @flow_task.as_json(:include => [:inputs, :outputs]), :status => status
      end
    end
  end
  
  def destroy
    @flow_task.destroy
    flash[:notice] = I18n.t( :task_deleted )
    redirect_back_or_default flow_tasks_path
  end
  
  private
  
  def load_flow_task
    return true if @flow_task = FlowTask.find_by_id(params[:id])
    flash[:error] = t( "views.shared.not_found.sorry_that_doesnt_exist" )
    redirect_to flow_tasks_path
    false
  end

  def require_owner
    unless logged_in? && ( current_user.id == @flow_task.user_id || current_user.is_admin? )
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      return redirect_to "/"
    end
  end
  
end
