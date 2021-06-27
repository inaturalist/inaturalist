class ModeratorNotesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :curator_required
  before_filter :load_record, except: [:create]
  before_filter :editor_required, except: [:create]

  layout "bootstrap"

  def create
    @moderator_note = ModeratorNote.new( approved_create_params )
    @moderator_note.user = current_user
    if @moderator_note.save
      flash[:notice] = t(:created)
    else
      flash[:error] = t(:failed_to_save_record_with_errors, errors: @moderator_note.errors.full_messages.to_sentence )
    end
    redirect_back_or_default root_url
  end

  def edit
  end

  def update
    if @moderator_note.update_attributes( approved_update_params )
      flash[:notice] = t(:updated)
    else
      flash[:error] = t(:failed_to_save_record_with_errors, errors: @moderator_note.errors.full_messages.to_sentence )
    end
    redirect_back_or_default person_path( @moderator_note.subject_user.login )
  end

  def destroy
    @moderator_note.destroy
    redirect_back_or_default person_path( @moderator_note.subject_user.login )
  end

  private
  def editor_required
    unless @moderator_note.editable_by?( current_user )
      flash[:error] = t(:you_dont_have_permission_to_do_that)
      return redirect_back_or_default person_path( @moderator_note.subject_user.login )
    end
  end
  def approved_create_params
    params.require(:moderator_note).permit(
      :body,
      :subject_user_id
    )
  end

  def approved_update_params
    params.require(:moderator_note).permit(
      :body
    )
  end
end
