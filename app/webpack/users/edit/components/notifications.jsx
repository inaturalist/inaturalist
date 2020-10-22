import React from "react";
import PropTypes from "prop-types";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";

const Notifications = ( {
  profile,
  handleCheckboxChange
} ) => (
  <div className="col-xs-9">
    <div className="row">
      <div className="col-md-5 col-xs-10">
        <SettingsItem header={I18n.t( "inaturalist_activity_notifications", { site_name: SITE.name } )} htmlFor="notifications">
          <label>{I18n.t( "notify_me_of_mentions" )}</label>
          <p className="text-muted">{I18n.t( "notify_me_of_mentions_description", { site_name: SITE.name } )}</p>
          <label>{I18n.t( "confirming_ids" )}</label>
          <p className="text-muted">{I18n.t( "confirming_ids_description" )}</p>
        </SettingsItem>
        <SettingsItem header={I18n.t( "email_notifications" )} htmlFor="notifications">
          <label>{I18n.t( "receive_email_notifications" )}</label>
          <p className="text-muted">{I18n.t( "receive_email_notifications_description", { site_name: SITE.name } )}</p>
          <CheckboxRowContainer
            name="prefers_comment_email_notification"
            label={I18n.t( "notification_preferences_comments" )}
          />
          <CheckboxRowContainer
            name="prefers_identification_email_notification"
            label={I18n.t( "notification_preferences_identifications" )}
          />
          <CheckboxRowContainer
            name="prefers_mention_email_notification"
            label={I18n.t( "notification_preferences_mentions" )}
          />
          <CheckboxRowContainer
            name="prefers_message_email_notification"
            label={I18n.t( "notification_preferences_messages" )}
          />
          <CheckboxRowContainer
            name="prefers_project_journal_post_email_notification"
            label={I18n.t( "notification_preferences_project_journal_posts" )}
          />
          <CheckboxRowContainer
            name="prefers_project_added_your_observation_email_notification"
            label={I18n.t( "notification_preferences_project_added_your_observations" )}
          />
          <CheckboxRowContainer
            name="prefers_project_curator_change_email_notification"
            label={I18n.t( "notification_preferences_project_curator_changes" )}
          />
          <CheckboxRowContainer
            name="prefers_taxon_change_email_notification"
            label={I18n.t( "notification_preferences_taxon_changes" )}
          />
          <CheckboxRowContainer
            name="prefers_user_observation_email_notification"
            label={I18n.t( "notification_preferences_user_observations" )}
          />
          <CheckboxRowContainer
            name="prefers_taxon_or_place_observation_email_notification"
            label={I18n.t( "notification_preferences_taxon_or_place_observations" )}
          />
        </SettingsItem>
      </div>
    </div>
  </div>
);

Notifications.propTypes = {
  profile: PropTypes.object,
  handleCheckboxChange: PropTypes.func
};

export default Notifications;
