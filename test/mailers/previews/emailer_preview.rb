#encoding: utf-8
class EmailerPreview < ActionMailer::Preview
  # Preview at /rails/mailers/emailer/updates_notification
  def updates_notification
    set_locale
    set_user
    recently_notified_user_id = UpdateAction.elastic_paginate(
      filters: [
        { exists: { field: :subscriber_ids } }
        # { term: { subscriber_ids: 1 } }
      ],
      per_page: 1,
      sort: { id: :desc },
      keep_es_source: true
    ).first.es_source.subscriber_ids.first
    @user = User.find(recently_notified_user_id)
    updates = @user.recent_notifications( per_page: 50 )
    Emailer.updates_notification(@user, updates)
  end

  def new_message
    set_locale
    # m = if message_id = @rack_env["QUERY_STRING"].to_s[/message_id=([^&]+)/, 1]
    #   Message.find_by_id(message_id)
    # end
    m = Message.where( to_user_id: 1, user_id: 1 ).first
    m ||= Message.last
    Emailer.new_message(m)
  end

  def observations_export_notification
    set_locale
    # ft = if (ftid = @rack_env["QUERY_STRING"].to_s[/flow_task_id=([^&]+)/, 1])
    #   FlowTask.find_by_id(ftid)
    # end
    ft ||= ObservationsExportFlowTask.includes(:outputs).where("flow_task_resources.id IS NOT NULL").last
    Emailer.observations_export_notification(ft)
  end

  def project_user_invitation
    set_locale
    # pui = if (id = @rack_env["QUERY_STRING"].to_s[/id=([^&]+)/, 1])
    #   ProjectUserInvitation.find_by_id(id)
    # end
    pui ||= ProjectUserInvitation.last
    Emailer.project_user_invitation(pui)
  end

  def confirmation_instructions
    # locale is determined by the user's locale
    set_user
    @user ||= User.first
    DeviseMailer.devise_mail(@user, :confirmation_instructions)
  end

  def bulk_observation_success
    set_locale
    @user ||= User.first
    Emailer.bulk_observation_success(@user, "some_file_name")
  end

  def bulk_observation_error
    set_locale
    @user ||= User.first
    bof = BulkObservationFile.new(nil, nil, nil, @user)
    o = Observation.new
    e = BulkObservationFile::BulkObservationException.new(
      "failed to process", 
      1, 
      [BulkObservationFile::BulkObservationException.new("observation was invalid", 1, o.errors)]
    )
    errors = bof.collate_errors(e)
    Emailer.bulk_observation_error(@user, "some_file_name", errors)
  end

  def parental_consent
    set_locale
    Emailer.parental_consent( "test@inaturalist.org" )
  end

  def user_parent_confirmation
    set_locale
    Emailer.user_parent_confirmation( UserParent.last )
  end

  def reset_password_instructions
    @user ||= User.first
    DeviseMailer.devise_mail( @user, :reset_password_instructions )
  end

  def unlock_instructions
    @user ||= User.first
    DeviseMailer.devise_mail( @user, :unlock_instructions )
  end

  def collection_project_changed_for_trusting_member
    set_locale
    Emailer.collection_project_changed_for_trusting_member( ProjectUser.last )
  end

  def curator_application
    lorem = <<-EOT
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
      tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim
      veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
      commodo consequat. Duis aute irure dolor in reprehenderit in voluptate
      velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat
      cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id
      est laborum.
    EOT
    Emailer.curator_application( User.last, {
      explanation: lorem,
      taxonomy_examples: lorem,
      name_examples: lorem,
      moderation_examples: lorem
    } )
  end

  def welcome
    Emailer.welcome( User.last )
  end

  private
  def set_user
    # @user = if login = @rack_env["QUERY_STRING"].to_s[/login=([^&]+)/, 1]
    #   User.find_by_login(login)
    # end
  end

  def set_locale
    # if locale = @rack_env["QUERY_STRING"].to_s[/locale=([^&]+)/, 1]
    #   I18n.locale = locale
    # end
  end
end
