class ProjectInvitationsController < ApplicationController
  before_filter :authenticate_user!

  def index
    @project_invitations = ProjectInvitation.
      includes(:observation).
      where("observations.user_id = ?", current_user).
      page(params[:page]).
      order("project_invitations.id DESC")
    @invitations_by_you = ProjectInvitation.
      includes(:observation).
      where("user_id = ?", current_user).
      limit(10).
      order("project_invitations.id DESC").
      group_by(&:project)
  end
  
  def create
    unless logged_in? && current_user.project_users.find_by_project_id(params[:project_id])
      flash[:error] = "You don't have permission to invite that observation."
      redirect_to :back and return
    end
    if ProjectInvitation.first(:conditions => {:observation_id => params[:observation_id], :project_id => params[:project_id]})
      flash[:error] = "This observation was already invited to this project"
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
    respond_to do |format|
      format.html do
        flash[:notice] = "Observation invited"
        redirect_to :back and return
      end
      format.json { render :json => @project_invitation }
    end
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
    
    unless @project_user = current_user.project_users.find_by_project_id(@project_invitation.project.id)
      #Need to join
      return redirect_to join_project_path(@project_invitation.project, :observation_id => @project_invitation.observation.id)
    end
    
    @project_observation = ProjectObservation.create(:project => @project_invitation.project, :observation => @project_invitation.observation)
    unless @project_observation.valid?
      flash[:error] = "There were problems adding your observation to this project: " + 
        @project_observation.errors.full_messages.to_sentence
      redirect_back_or_default(@project_observation.observation)
      return
    end
    
    @project_invitation.destroy
    flash[:notice] = "Observation added to the project \"#{@project_invitation.project.title}\""
    redirect_back_or_default(@project_observation.observation)
  end
  
  def destroy
    unless @project_invitation = ProjectInvitation.find(params[:id])
      @error = "That project invitation doesn't exist."
    end

    unless @project_invitation.observation.user_id == current_user.id || @project_invitation.user_id == current_user.id || ProjectUser.first(:conditions => {:project_id => @project_invitation.project_id, :user_id => current_user.id , :role => "curator"})
      @error = "You don't have permission to remove that project invitation."
    end

    if @error
      respond_to do |format|
        format.any(:html, :mobile) do
          flash[:error] = @error
          redirect_back_or_default('/')
        end
        format.json { render :json => {:error => @error} }
      end
      return
    end
    
    @project_invitation.destroy
    respond_to do |format|
      format.any(:html, :mobile) do
        flash[:notice] = "Invitation to the project \"#{@project_invitation.project.title}\" removed"
        redirect_back_or_default('/')
      end
      format.json { render :json => @project_invitation }
    end
  end
end
