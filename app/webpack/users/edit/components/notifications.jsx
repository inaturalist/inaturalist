import React from "react";
import PropTypes from "prop-types";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import ToggleSwitchContainer from "../containers/toggle_switch_container";

const Notifications = ( { profile } ) => (
  <div className="row">
    <div className="col-xs-12 col-md-10">
      <SettingsItem>
        <h4>{I18n.t( "inaturalist_activity_notifications", { site_name: SITE.name } )}</h4>
        <div className="row stacked">
          <div className="col-sm-9">
            <label>{I18n.t( "notify_me_of_mentions" )}</label>
            <p className="text-muted">{I18n.t( "notify_me_of_mentions_description", { site_name: SITE.name } )}</p>
          </div>
          <ToggleSwitchContainer
            name="prefers_receive_mentions"
            checked={profile.prefers_receive_mentions}
          />
        </div>
        <div className="row">
          <div className="col-sm-9">
            <label>{I18n.t( "confirming_ids" )}</label>
            <p className="text-muted">{I18n.t( "confirming_ids_description" )}</p>
          </div>
          <ToggleSwitchContainer
            name="prefers_redundant_identification_notifications"
            checked={profile.prefers_redundant_identification_notifications}
          />
        </div>
      </SettingsItem>
      <SettingsItem>
        <h4>{I18n.t( "email_notifications" )}</h4>
        <div className="row">
          <div className="col-sm-9">
            <label>{I18n.t( "receive_email_notifications" )}</label>
            <p className="text-muted">{I18n.t( "receive_email_notifications_description", { site_name: SITE.name } )}</p>
          </div>
          <ToggleSwitchContainer
            name="prefers_no_email"
            checked={!profile.prefers_no_email}
          />
        </div>
        <div className={profile.prefers_no_email ? "collapse" : null}>
          <CheckboxRowContainer
            name="prefers_comment_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_comments" )}
          />
          <CheckboxRowContainer
            name="prefers_identification_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_identifications" )}
          />
          <CheckboxRowContainer
            name="prefers_mention_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_mentions" )}
          />
          <CheckboxRowContainer
            name="prefers_message_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_messages" )}
          />
          <CheckboxRowContainer
            name="prefers_project_journal_post_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_project_journal_posts" )}
          />
          <CheckboxRowContainer
            name="prefers_project_added_your_observation_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_project_added_your_observations" )}
          />
          <CheckboxRowContainer
            name="prefers_project_curator_change_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_project_curator_changes" )}
          />
          <CheckboxRowContainer
            name="prefers_taxon_change_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_taxon_changes" )}
          />
          <CheckboxRowContainer
            name="prefers_user_observation_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_user_observations" )}
          />
          <CheckboxRowContainer
            name="prefers_taxon_or_place_observation_email_notification"
            label={I18n.t( "views.users.edit.notification_preferences_taxon_or_place_observations" )}
          />
        </div>
      </SettingsItem>
    </div>
  </div>
);

Notifications.propTypes = {
  profile: PropTypes.object
};

export default Notifications;
