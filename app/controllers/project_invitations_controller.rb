class ProjectInvitationsController < ApplicationController
  
  def create
    unless logged_in? && current_user.project_users.find_by_project_id(params[:project_id])
      flash[:error] = "You don't have permission to invite that observation."
      redirect_to :back and return
    end
    if ProjectInvitation.first(:conditions => {:observation_id => params[:observation_id], :project_id => params[:project_id], :user_id => params[:user_id]})
      flash[:error] = "This observation was already invited"
      redirect_to :back and return
    end
    if ProjectObservation.first(:conditions => {:observation_id => params[:observation_id], :project_id => params[:project_id]})
        flash[:error] = "This observation was already added"
        redirect_to :back and return
    end
    @project_invitation = ProjectInvitation.new(:observation_id => params[:observation_id], :project_id => params[:project_id], :user_id => params[:user_id])
    unless @project_invitation.save
      flash[:error] = "There was a problem adding your observation"
      redirect_to :back and return
    end
    flash[:notice] = "Observation invited"
    redirect_to :back and return
  end
  
  def accept
    unless @project_invitation = ProjectInvitation.find(params[:id])
      flash[:error] = "That project invitation doesn't exist."
      redirect_to :back and return
    end
    unless logged_in? && current_user.id == @project_invitation.observation.user_id
      flash[:error] = "You don't have permission to accept that invitation."
      return redirect_to @project_invitation.observation
    end
    @project_user = current_user.project_users.find_or_create_by_project_id(@project_invitation.project.id)
    unless @project_user && @project_user.valid?
      flash[:error] = "There was a problem"
      redirect_to :back and return
    end
    
    @project_observation = ProjectObservation.create(:project => @project_invitation.project, :observation => @project_invitation.observation)
    unless @project_observation.valid?
      flash[:error] = "There were problems adding your observation to this project: " + 
        @project_observation.errors.full_messages.to_sentence
      redirect_to :back and return
    end
    
    @project_invitation.destroy
    flash[:notice] = "Observation added to the project \"#{@project_invitation.project.title}\""
    redirect_to :back
  end
  
  def destroy
    unless @project_invitation = ProjectInvitation.find(params[:id])
      flash[:error] = "That project invitation doesn't exist."
      redirect_to :back and return
    end
    unless @project_invitation.observation.user_id == current_user.id || @project_invitation.user_id == current_user.id || ProjectUser.first(:conditions => {:project_id => @project_invitation.project_id, :user_id => current_user.id , :role => "curator"})
      flash[:error] = "You don't have permission to remove that project invitation."
      redirect_to :back and return
    end
    
    @project_invitation.destroy
    flash[:notice] = "Invitation to the project \"#{@project_invitation.project.title}\" removed"
    redirect_to :back
  end
end
