import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

// import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

const Content = ( { profile, setUserData } ) => {
  const handleNameChange = e => {
    console.log( e.target );
  };

  const handleInputChange = e => {
    const updatedProfile = profile;
    updatedProfile[e.target.name] = e.target.value;
    setUserData( updatedProfile );
  };

  const handleCheckboxChange = e => {
    const updatedProfile = profile;
    updatedProfile[e.target.name] = e.target.checked;
    setUserData( updatedProfile );
  };

  const handlePlaceDropdownSelect = ( { item } ) => {
    const updatedProfile = profile;
    updatedProfile.place_id = item.id;
    setUserData( updatedProfile );
  };

  const handleSelect = eventKey => {
    const updatedProfile = profile;
    updatedProfile.site_id = eventKey;
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

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <div className="settings-item">
            <h5>{I18n.t( "project_settings" )}</h5>
            <label>{I18n.t( "which_projects_can_add_your_observations?" )}</label>
            <div className="left-aligned-column">
              <form>
                <div className="form-check">
                  <label>
                    <input
                      type="radio"
                      className="form-check-input"
                      value="any"
                      name="preferred_project_addition_by"
                      checked={profile.preferred_project_addition_by === "any"}
                      onChange={handleInputChange}
                    />
                    {I18n.t( "views.users.edit.project_addition_preferences.any" )}
                  </label>
                </div>
                <div className="form-check">
                  <label>
                    <input
                      type="radio"
                      className="form-check-input"
                      value="joined"
                      name="preferred_project_addition_by"
                      checked={profile.preferred_project_addition_by === "joined"}
                      onChange={handleInputChange}
                    />
                    {I18n.t( "views.users.edit.project_addition_preferences.joined" )}
                  </label>
                </div>
                <div className="form-check">
                  <label>
                    <input
                      type="radio"
                      className="form-check-input"
                      value="none"
                      name="preferred_project_addition_by"
                      checked={profile.preferred_project_addition_by === "none"}
                      onChange={handleInputChange}
                    />
                    {I18n.t( "views.users.edit.project_addition_preferences.none" )}
                  </label>
                </div>
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
          </div>
          <div className="settings-item">
            <h5>{I18n.t( "taxonomy_settings" )}</h5>
            <div className="row">
              <div className="col-xs-1">
                <input
                  type="checkbox"
                  className="form-check-input"
                  checked={profile.prefers_automatic_taxon_changes}
                  name="prefers_automatic_taxon_changes"
                  onChange={handleCheckboxChange}
                />
              </div>
              <div className="col-xs-10">
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
          </div>
          <div className="settings-item">
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
          <div className="settings-item">
            <h5>{I18n.t( "names" )}</h5>
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
          </div>
          <div className="settings-item">
            <h5>{I18n.t( "community_moderation_settings" )}</h5>
            <div className="col-xs-1">
              <input
                type="checkbox"
                className="form-check-input"
                value={profile.prefers_community_taxa}
                name="prefers_community_taxa"
                checked={profile.prefers_community_taxa}
                onChange={handleInputChange}
              />
            </div>
            <div className="col-xs-9">
              <label>{I18n.t( "accept_community_identifications" )}</label>
              <div className="account-subheader-text">{I18n.t( "views.users.edit.prefers_community_taxa_desc", { site_name: SITE.short_name || SITE.name } )}</div>
            </div>
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
