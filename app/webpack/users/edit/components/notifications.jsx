import React from "react";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import ToggleSwitchContainer from "../containers/toggle_switch_container";

const Notifications = ( ) => (
  <div className="col-xs-9">
    <div className="row">
      <div className="col-xs-10">
        <SettingsItem header={I18n.t( "inaturalist_activity_notifications", { site_name: SITE.name } )} htmlFor="notifications">
          <div className="row">
            <div className="col-xs-9">
              <label>{I18n.t( "notify_me_of_mentions" )}</label>
              <p className="text-muted">{I18n.t( "notify_me_of_mentions_description", { site_name: SITE.name } )}</p>
            </div>
            <ToggleSwitchContainer name="prefers_receive_mentions" />
          </div>
          <div className="row">
            <div className="col-xs-9">
              <label>{I18n.t( "confirming_ids" )}</label>
              <p className="text-muted">{I18n.t( "confirming_ids_description" )}</p>
            </div>
            <ToggleSwitchContainer name="prefers_redundant_identification_notifications" />
          </div>
        </SettingsItem>
        <SettingsItem header={I18n.t( "email_notifications" )} htmlFor="notifications">
          <div className="row">
            <div className="col-xs-9">
              <label>{I18n.t( "receive_email_notifications" )}</label>
              <p className="text-muted">{I18n.t( "receive_email_notifications_description", { site_name: SITE.name } )}</p>
            </div>
            <ToggleSwitchContainer name="prefers_no_email" />
          </div>
          <CheckboxRowContainer
            name="prefers_comment_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_comments" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_identification_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_identifications" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_mention_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_mentions" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_message_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_messages" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_project_journal_post_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_project_journal_posts" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_project_added_your_observation_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_project_added_your_observations" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_project_curator_change_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_project_curator_changes" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_taxon_change_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_taxon_changes" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_user_observation_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_user_observations" )}
          />
          <p />
          <CheckboxRowContainer
            name="prefers_taxon_or_place_observation_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_taxon_or_place_observations" )}
          />
        </SettingsItem>
      </div>
    </div>
  </div>
);

export default Notifications;
