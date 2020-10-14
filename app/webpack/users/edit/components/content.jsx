import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";

// import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

const Content = ( { profile, setUserData, handleInputChange } ) => {
  const handleNameChange = e => {
    console.log( e.target );
  };

  const handlePlaceDropdownSelect = ( { item } ) => {
    const updatedProfile = profile;
    updatedProfile.place_id = item.id;
    setUserData( updatedProfile );
  };

  const createDisplayNamesList = ( ) => {
    const italicText = I18n.t( "scientific_name" );

    const displayNames = [{
      option: 1,
      text: I18n.t( "common_name" ),
      parentheses: ` (${italicText})`
    },
    {
      option: 2,
      text: italicText,
      parentheses: ` (${I18n.t( "common_name" )})`
    },
    {
      option: 3,
      text: italicText,
      parentheses: null
    }];

    return displayNames.map( ( { option, text, parentheses } ) => (
      <MenuItem
        key={`display-names-${option}`}
        eventKey={option}
        className="inat-affiliation-width"
      >
        <span className="row-align-center">
          {text}
          {parentheses && <div className="italic-text">{parentheses}</div>}
          <i className="fa fa-check blue-text align-right" aria-hidden="true" />
        </span>
      </MenuItem>
    ) );
  };

  const createRadioButtons = ( ) => ["any", "joined", "none"].map( button => (
    <div className="form-check">
      <label>
        <input
          type="radio"
          className="form-check-input"
          value={button}
          name="preferred_project_addition_by"
          checked={profile.preferred_project_addition_by === button}
          onChange={handleInputChange}
        />
        {I18n.t( `views.users.edit.project_addition_preferences.${button}` )}
      </label>
    </div>
  ) );

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <SettingsItem header={I18n.t( "project_settings" )}>
            <label>{I18n.t( "which_projects_can_add_your_observations?" )}</label>
            <div className="left-aligned-column">
              <form>
                {createRadioButtons( )}
              </form>
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
          </SettingsItem>
          <SettingsItem header={I18n.t( "taxonomy_settings" )}>
            <CheckboxRowContainer
              name="prefers_automatic_taxon_changes"
              label={I18n.t( "automatically_update_my_content_for_taxon_changes" )}
              description={(
                <div>
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
              )}
            />
          </SettingsItem>
          <SettingsItem header={I18n.t( "licensing" )}>
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
            <label>{I18n.t( "default_observation_license" )}</label>
            <label>{I18n.t( "default_photo_license" )}</label>
            <label>{I18n.t( "default_sound_license" )}</label>
          </SettingsItem>
        </div>
        <div className="col-md-1" />
        <div className="col-md-6 col-xs-10">
          <SettingsItem header={I18n.t( "names" )}>
            <label>{I18n.t( "display" )}</label>
            <div className="account-subheader-text">{I18n.t( "this_is_how_taxon_names_will_be_displayed", { site_name: SITE.name } )}</div>
            <DropdownButton
              id="display-names-dropdown"
              onSelect={handleNameChange}
              className="inat-affiliation-width-height"
              title={(
                <span>
                  common names
                </span>
              )}
            >
              {createDisplayNamesList( )}
            </DropdownButton>
            <div>
              <label>{I18n.t( "views.users.edit.name_place_help_html" )}</label>
              {/* <PlaceAutocomplete
                // resetOnChange={false}
                initialPlaceID={profile.place_id}
                bootstrapClear
                afterSelect={handlePlaceDropdownSelect}
              /> */}
            </div>
          </SettingsItem>
          <SettingsItem header={I18n.t( "community_moderation_settings" )}>
            <CheckboxRowContainer
              name="prefers_community_taxa"
              label={I18n.t( "accept_community_identifications" )}
              description={(
                <div className="account-subheader-text">
                  {I18n.t( "views.users.edit.prefers_community_taxa_desc", { site_name: SITE.short_name || SITE.name } )}
                </div>
              )}
            />
            <label>{I18n.t( "who_can_add_observation_fields_to_my_obs" )}</label>
            <div className="account-subheader-text">{I18n.t( "observation_fields_by_preferences_description" )}</div>
            <select
              value={profile.preferred_observation_fields_by}
              name="preferred_observation_fields_by"
              onChange={handleInputChange}
            >
              <option value="anyone">{I18n.t( "anyone" )}</option>
              <option value="curators">{I18n.t( "curators" )}</option>
              <option value="only_you">{I18n.t( "only_you" )}</option>
            </select>
          </SettingsItem>
        </div>
      </div>
    </div>
  );
};

Content.propTypes = {
  profile: PropTypes.object,
  setUserData: PropTypes.func,
  handleInputChange: PropTypes.func
};

export default Content;
