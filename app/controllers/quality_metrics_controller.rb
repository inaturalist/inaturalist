class QualityMetricsController < ApplicationController
  before_filter :login_required
  
  def vote
    unless @observation = Observation.find_by_id(params[:id])
      msg = "Observation does not exist."
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_back_or_default('/')
        end
        format.json { render :json => {:error => msg} }
      end
    end
    
    if existing = @observation.quality_metrics.first(:conditions => {:user_id => current_user.id, :metric => params[:metric]})
      existing.destroy
    end
    
    if request.delete?
      respond_to do |format|
        format.html do
          flash[:notice] = "Metric removed."
          redirect_back_or_default(@observation)
        end
        format.json { render :json => qm }
      end
      return
    end
    
    qm = @observation.quality_metrics.build(:user_id => current_user.id, 
      :metric => params[:metric], :agree => params[:agree] != "false")
    if qm.save
      respond_to do |format|
        format.html do
          flash[:notice] = "Metric added."
          redirect_back_or_default(@observation)
        end
        format.json { render :json => qm }
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
end
