import React from "react";
import PropTypes from "prop-types";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import ToggleSwitchContainer from "../containers/toggle_switch_container";

const Notifications = ( { userSettings } ) => (
  <div className="row Notifications">
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
            checked={userSettings.prefers_receive_mentions}
          />
        </div>
        <div className="row stacked">
          <div className="col-sm-9">
            <label>{I18n.t( "confirming_ids" )}</label>
            <p className="text-muted">{I18n.t( "confirming_ids_description" )}</p>
          </div>
          <ToggleSwitchContainer
            name="prefers_redundant_identification_notifications"
            checked={userSettings.prefers_redundant_identification_notifications}
          />
        </div>
        <div className="row">
          <div className="col-sm-9">
            <label>{I18n.t( "infraspecies_ids" )}</label>
            <p className="text-muted">{I18n.t( "infraspecies_ids_description" )}</p>
          </div>
          <ToggleSwitchContainer
            name="prefers_infraspecies_identification_notifications"
            checked={userSettings.prefers_infraspecies_identification_notifications}
          />
        </div>
        <div className="row">
          <div className="col-sm-9">
            <label>{I18n.t( "non_disagreeing_ancestor_ids" )}</label>
            <p className="text-muted">{I18n.t( "non_disagreeing_ancestor_ids_description" )}</p>
          </div>
          <ToggleSwitchContainer
            name="prefers_non_disagreeing_identification_notifications"
            checked={userSettings.prefers_non_disagreeing_identification_notifications}
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
            checked={!userSettings.prefers_no_email}
          />
        </div>
        <div className={userSettings.prefers_no_email ? "collapse" : null}>
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

      <div className="admin stacked">
        <SettingsItem>
          <h4>{I18n.t( "email_notifications" )}</h4>
          <div className="row">
            <div className="col-sm-9">
              <label>{I18n.t( "messages" )}</label>
              <p className="text-muted">{I18n.t( "prefers_message_email_notification_desc" )}</p>
            </div>
            <ToggleSwitchContainer
              name="prefers_message_email_notification"
              checked={userSettings.prefers_message_email_notification}
            />
          </div>
          <div className="row">
            <div className="col-sm-9">
              <label>{I18n.t( "activity" )}</label>
              <p className="text-muted">{I18n.t( "prefers_activity_email_notification_desc" )}</p>
            </div>
            <ToggleSwitchContainer
              name="prefers_activity_email_notification"
              checked={userSettings.prefers_activity_email_notification}
            />
          </div>
          <div className={userSettings.prefers_activity_email_notification ? null : "collapse"}>
            <fieldset>
              <legend>Types</legend>
              <div className="row>">
                <div className="col-sm-6">
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
                    name="prefers_user_observation_email_notification"
                    label={I18n.t( "views.users.edit.notification_preferences_user_observations" )}
                  />
                  <CheckboxRowContainer
                    name="prefers_taxon_or_place_observation_email_notification"
                    label={I18n.t( "views.users.edit.notification_preferences_taxon_or_place_observations" )}
                  />
                </div>
                <div className="col-sm-6">
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
                </div>
              </div>
            </fieldset>
          </div>
        </SettingsItem>
        <SettingsItem>
          <h4>Occasional Emails</h4>
          <div className="row">
            <div className="col-sm-9">
              <label>News</label>
              <p className="text-muted">News about the organization and the platform.</p>
            </div>
            <ToggleSwitchContainer
              name="email_suppression_news_from_inaturalist"
              checked={!userSettings.email_suppression_types?.includes( "news_from_inaturalist" )}
            />
          </div>
          <div className="row">
            <div className="col-sm-9">
              <label>Donations</label>
              <p className="text-muted">iNat is free to use, but it costs money to run, so sometimes we might ask you to pitch in a few bucks.</p>
            </div>
            <ToggleSwitchContainer
              name="email_suppression_donation_emails"
              checked={!userSettings.email_suppression_types?.includes( "donation_emails" )}
            />
          </div>
          <div className="row">
            <div className="col-sm-9">
              <label>Feedback</label>
              <p className="text-muted">We love hearing from you, so we might ask for your opinion on specific topics.</p>
            </div>
            <ToggleSwitchContainer
              name="email_suppression_feedback_emails"
              checked={!userSettings.email_suppression_types?.includes( "feedback_emails" )}
            />
          </div>
        </SettingsItem>
        <SettingsItem>
          <h4>Bonus Emails</h4>
          <code>These don't work yet, FYI</code>
          <div className="row">
            <div className="col-sm-9">
              <label>Monthly Newsletter</label>
              <p className="text-muted">Monthly updates about what people have been doing on iNat and with iNat data.</p>
            </div>
            <ToggleSwitchContainer
              name="email_suppression_monthly_newsletter"
              checked={userSettings.prefers_monthly_newsletter && !userSettings.email_suppression_types?.includes( "monthly_newsletter" )}
            />
          </div>
          <div className="row">
            <div className="col-sm-9">
              <label>Phenology Newsletter</label>
              <p className="text-muted">Learn about... phenology? IDK what this is really about.</p>
            </div>
            <ToggleSwitchContainer
              name="email_suppression_phenology_newsletter"
              checked={userSettings.prefers_phenology_newsletter && !userSettings.email_suppression_types?.includes( "phenology_newsletter" )}
            />
          </div>
        </SettingsItem>
      </div>
    </div>
  </div>
);

Notifications.propTypes = {
  userSettings: PropTypes.object
};

export default Notifications;
