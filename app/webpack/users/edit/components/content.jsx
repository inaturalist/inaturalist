import React from "react";
import PropTypes from "prop-types";

/* global SITE */

const Content = ( { profile, setUserData } ) => {
  console.log( SITE, "site" );
  // const handleInputChange = e => {
  //   const updatedProfile = profile;
  //   updatedProfile[e.target.name] = e.target.value;
  //   setUserData( updatedProfile );
  // };

  const handleCheckboxChange = e => {
    const updatedProfile = profile;
    updatedProfile[e.target.name] = e.target.checked;
    setUserData( updatedProfile );
  };

  // const handleSelect = eventKey => {
  //   // const updatedProfile = profile;
  //   // updatedProfile.site_id = eventKey;
  //   // setUserData( updatedProfile );
  // };

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "project_settings" )}</h5>
            <label>{I18n.t( "which_projects_can_add_your_observations?" )}</label>
            <div className="left-aligned-column">
              <div className="save-button">
                <input type="radio" className="radio-button" id="any" name="preferred_project_addition_by" value="any_project" />
                <label htmlFor="any">{I18n.t( "views.users.edit.project_addition_preferences.any" )}</label>
              </div>
              <div className="save-button">
                <input type="radio" className="radio-button" id="joined" name="preferred_views.users.edit._addition_by" value="projects_you_joined" />
                <label htmlFor="joined">{I18n.t( "views.users.edit.project_addition_preferences.joined" )}</label>
              </div>
              <div className="save-button">
                <input type="radio" className="radio-button" id="none" name="preferred_project_addition_by" value="none" />
                <label htmlFor="none">{I18n.t( "views.users.edit.project_addition_preferences.none" )}</label>
              </div>
            </div>
            <div className="account-subheader-text">
              {I18n.t( "views.users.edit.project_settings_desc" )}
            </div>
            <span
              className="account-subheader-text"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.this_only_applies_to_traditional_projects", {
                  url: "https://www.inaturalist.org/blog/15450-announcing-changes-to-projects-on-inaturalist"
                } )
              }}
            />
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "taxonomy_settings" )}</h5>
            <div className="col-xs-1">
              <input
                type="checkbox"
                className="form-check-input"
                defaultChecked={profile.prefers_automatic_taxon_changes}
                name="prefers_automatic_taxon_changes"
                onChange={handleCheckboxChange}
              />
            </div>
            <div className="col-xs-9">
              <label>{I18n.t( "automatically_update_my_content_for_taxon_changes" )}</label>
              <span
                className="account-subheader-text"
                // eslint-disable-next-line react/no-danger
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.users.edit.taxon_change_desc", {
                    site_name: SITE.name
                  } )
                }}
              />
            </div>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "licensing" )}</h5>
            <span
              className="account-subheader-text"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.licensing_desc_html", {
                  site_name: SITE.name
                } )
              }}
            />
            <a href="#">{I18n.t( "learn_what_these_licenses_mean" )}</a>
          </div>
        </div>
        <div className="col-md-1" />
        <div className="col-md-6 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "names" )}</h5>
            <label>{I18n.t( "display" )}</label>
            <div className="account-subheader-text">{I18n.t( "this_is_how_taxon_names_will_be_displayed", { site_name: SITE.name } )}</div>
            <label>{I18n.t( "views.users.edit.name_place_help_html" )}</label>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "community_moderation_settings" )}</h5>
            <label>{I18n.t( "accept_community_identifications" )}</label>
            <div className="account-subheader-text">{I18n.t( "views.users.edit.prefers_community_taxa_desc", { site_name: SITE.short_name || SITE.name } )}</div>
            <label>{I18n.t( "who_can_add_observation_fields_to_my_obs" )}</label>
            <div className="account-subheader-text">{I18n.t( "observation_fields_by_preferences_description" )}</div>
            <select>
              <option>{I18n.t( "anyone" )}</option>
              <option>{I18n.t( "curators" )}</option>
              <option>{I18n.t( "only_you" )}</option>
            </select>
          </div>
        </div>
      </div>
    </div>
  );
};

Content.propTypes = {
  profile: PropTypes.object,
  setUserData: PropTypes.func
};

export default Content;
