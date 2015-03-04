class QualityMetricsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :return_here, :except => [:vote]
  before_filter :load_observation
  
  def vote
    if @existing = @observation.quality_metrics.where(user_id: current_user.id, metric: params[:metric]).first
      @existing.destroy
    end
    
    if request.delete?
      respond_to_destroy
      return
    end
    respond_to_create
  end
  
  private
  
  def respond_to_destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Metric removed."
        redirect_back_or_default(@observation)
      end
      format.json do
        render :json => {
          :object => @existing,
          :html => render_to_string(:partial => "quality_metric_row.html.erb", :locals => {
            :metric => params[:metric], 
            :question => QualityMetric::METRIC_QUESTIONS[params[:metric]], 
            :existing_quality_metrics => @observation.quality_metrics.all,
            :observation => @observation
          })
        }
      end
    end
  end
  
  def respond_to_create
    qm = @observation.quality_metrics.build(:user_id => current_user.id, 
      :metric => params[:metric], :agree => params[:agree] != "false")
    if qm.save
      respond_to do |format|
        format.html do
          flash[:notice] = "Metric added."
          redirect_back_or_default(@observation)
        end
        format.json do
          render :json => {
            :object => qm,
            :html => render_to_string(:partial => "quality_metric_row.html.erb", :locals => {
              :metric => qm.metric, 
              :question => QualityMetric::METRIC_QUESTIONS[qm.metric], 
              :existing_quality_metrics => @observation.quality_metrics.all,
              :user_quality_metric => qm,
              :observation => @observation
            })
          }
        end
      end
    else
      msg = "Couldn't add that metric: #{qm.errors.full_messages.to_sentence}"
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_back_or_default(@observation)
        end
        format.json { render :json => {:error => msg, :object => qm} }
      end
    end
  end
  
  def load_observation
    return true if @observation = Observation.find_by_id(params[:id])
    msg = "Observation does not exist."
    respond_to do |format|
      format.html do
        flash[:error] = msg
        redirect_back_or_default('/')
      end
      format.json { render :json => {:error => msg} }
    end
    false
  end
end
