class ProjectUserInvitationsController < ApplicationController
  before_filter :load_record, :only => [:destroy]
  before_filter :load_project
  before_filter :ensure_project_curator
  
  def create
    @project_user_invitation = ProjectUserInvitation.new(params[:project_user_invitation])
    @project_user_invitation.user = current_user
    respond_to do |format|
      if @project_user_invitation.save
        format.html do
          flash[:notice] = t(:invited_x, :x => @project_user_invitation.invited_user.login)
          redirect_back_or_default @project
        end
        format.json { render :json => @project_user_invitation }
      else
        format.html do
          flash[:error] = @project_user_invitation.errors.full_messages.to_sentence
          redirect_back_or_default @project
        end
        format.json do
          render :status => :unprocessable_entity, :error => @project_user_invitation.errors.full_messages.to_sentence
        end
      end
    end
  end

  def destroy
    @project_user_invitation.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = t(:x_deleted, :x => t(:invitation))
        redirect_back_or_default @project
      end
      format.json { head :no_content }
    end
  end

  private

  def load_project
    @project = @project_user_invitation.try(:project)
    if @project.blank? && params[:project_user_invitation]
      @project = Project.find_by_id(params[:project_user_invitation][:project_id])
    end
    if @project.blank?
      respond_to do |format|
        msg = t(:that_project_doesnt_exist)
        format.html do
          flash[:error] = msg
          redirect_back_or_default projects_path
        end
        format.json do
          render :status => :unprocessable_entity, :error => msg
        end
      end
      return false
    end
  end

  def ensure_project_curator
    unless @project.curated_by?(current_user)
      respond_to do |format|
        msg = t(:only_project_curators_can_do_that)
        format.html do
          flash[:error] = msg
          redirect_back_or_default @project
        end
        format.json do
          render :status => :unprocessable_entity, :error => msg
        end
      end
      return false
    end
  end
end
