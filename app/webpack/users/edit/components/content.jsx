import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import LicenseImageRow from "./license_image_row";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";
import TaxonNamePreferencesContainer from "../containers/taxon_name_preferences_container";

const radioButtons = {
  any: I18n.t( "views.users.edit.project_addition_preferences.any" ),
  joined: I18n.t( "views.users.edit.project_addition_preferences.joined" ),
  none: I18n.t( "views.users.edit.project_addition_preferences.none" )
};

const obsFields = {
  anyone: I18n.t( "anyone" ),
  curators: I18n.t( "curators" ),
  observer: I18n.t( "only_you" )
};

const Content = ( {
  config,
  profile,
  handleInputChange,
  handleCustomDropdownSelect,
  handleDisplayNames,
  handlePlaceAutocomplete,
  showModal
} ) => {
  const iNatLicenses = iNaturalist.Licenses;
  const licenseList = ["cc0", "cc-by", "cc-by-nc", "cc-by-nc-sa", "cc-by-nc-nd", "cc-by-nd", "cc-by-sa", "c"];

  const createRadioButtons = ( ) => Object.keys( radioButtons ).map( button => (
    <div className="radio" key={button}>
      <label className="radio-button">
        <input
          id="user_preferred_project_addition_by"
          type="radio"
          value={button}
          name="preferred_project_addition_by"
          checked={profile.preferred_project_addition_by === button}
          onChange={handleInputChange}
        />
        {radioButtons[button]}
      </label>
    </div>
  ) );

  const showDefaultLicense = defaultLicense => {
    const current = Object.keys( iNatLicenses )
      .find( i => iNatLicenses[i].code === defaultLicense );
    const license = defaultLicense === null ? "c" : current;

    return (
      <div className="current-license">
        <LicenseImageRow license={license} />
        <div className="caret" />
      </div>
    );
  };

  const createLicenseList = name => licenseList.map( license => {
    const { code } = iNatLicenses[license];

    return (
      <MenuItem
        key={`${name}-${license}`}
        eventKey={code}
      >
        <LicenseImageRow license={license} />
        {profile[name] === code && <i className="fa fa-check blue-checkmark" aria-hidden="true" />}
      </MenuItem>
    );
  } );

  const setDisplayName = ( ) => {
    if ( profile.prefers_common_names ) {
      if ( !profile.prefers_scientific_name_first ) {
        return "prefers_common_names";
      }
      return "prefers_scientific_name_first";
    }
    return "prefers_scientific_names";
  };

  return (
    <div className="row">
      <div className="col-md-5 col-xs-10">
        <SettingsItem>
          <h4>{I18n.t( "project_settings" )}</h4>
          <div className="stacked">
            <label htmlFor="user_preferred_project_addition_by">{I18n.t( "which_projects_can_add_your_observations?" )}</label>
          </div>
          <div className="stacked">
            {createRadioButtons( )}
          </div>
          <p className="text-muted">{I18n.t( "views.users.edit.project_settings_desc" )}</p>
          <p
            className="text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.users.edit.this_only_applies_to_traditional_projects" )
            }}
          />
        </SettingsItem>
        <SettingsItem>
          <h4>{I18n.t( "taxonomy_settings" )}</h4>
          <CheckboxRowContainer
            name="prefers_automatic_taxonomic_changes"
            label={I18n.t( "automatically_update_my_content_for_taxon_changes" )}
            description={(
              <p
                className="text-muted"
                // eslint-disable-next-line react/no-danger
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.users.edit.taxon_change_desc", {
                    site_name: SITE.name
                  } )
                }}
              />
            )}
          />
        </SettingsItem>
        <SettingsItem>
          <h4>{I18n.t( "licensing" )}</h4>
          <p>
            <span
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.licensing_desc_html", {
                  site_name: SITE.name
                } )
              }}
            />
            <button
              type="button"
              className="btn btn-nostyle btn-link"
              id="about_licenses"
              onClick={showModal}
            >
              {I18n.t( "learn_what_these_licenses_mean" )}
            </button>
          </p>
          <div id="LicenseDropdown">
            <label htmlFor="preferred_observation_license">{I18n.t( "default_observation_license" )}</label>
            <div className="stacked">
              <DropdownButton
                id="preferred_observation_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_observation_license" )}
                title={showDefaultLicense( profile.preferred_observation_license )}
                noCaret
              >
                {createLicenseList( "preferred_observation_license" )}
              </DropdownButton>
            </div>
            <div className="stacked">
              <CheckboxRowContainer
                name="make_observation_licenses_same"
                label={I18n.t( "update_existing_observations_with_new_license" )}
              />
            </div>
            <label htmlFor="preferred_photo_license">{I18n.t( "default_photo_license" )}</label>
            <div className="stacked">
              <DropdownButton
                id="preferred_photo_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_photo_license" )}
                title={showDefaultLicense( profile.preferred_photo_license )}
                noCaret
              >
                {createLicenseList( "preferred_photo_license" )}
              </DropdownButton>
            </div>
            <div className="stacked">
              <CheckboxRowContainer
                name="make_photo_licenses_same"
                label={I18n.t( "update_existing_photos_with_new_license" )}
              />
            </div>
            <label htmlFor="preferred_sound_license">{I18n.t( "default_sound_license" )}</label>
            <div className="stacked">
              <DropdownButton
                id="preferred_sound_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_sound_license" )}
                title={showDefaultLicense( profile.preferred_sound_license )}
                noCaret
              >
                {createLicenseList( "preferred_sound_license" )}
              </DropdownButton>
            </div>
          </div>
          <CheckboxRowContainer
            name="make_sound_licenses_same"
            label={I18n.t( "update_existing_sounds_with_new_license" )}
          />
        </SettingsItem>
      </div>
      <div className="col-md-1" />
      <div className="col-md-5 col-xs-10">
        <SettingsItem>
          <h4>{I18n.t( "names" )}</h4>
          <div className="stacked">
            <label htmlFor="user_prefers_common_names">{I18n.t( "display" )}</label>
          </div>
          <div className="text-muted stacked">{I18n.t( "this_is_how_taxon_names_will_be_displayed", { site_name: SITE.name } )}</div>
          <select
            className="form-control stacked dropdown"
            id="user_prefers_common_names"
            name="prefers_common_names"
            onChange={handleDisplayNames}
            value={setDisplayName( )}
          >
            <option value="prefers_common_names">{`${I18n.t( "common_name" )} (${I18n.t( "scientific_name" )})`}</option>
            <option value="prefers_scientific_name_first">{`${I18n.t( "scientific_name" )} (${I18n.t( "common_name" )})`}</option>
            <option value="prefers_scientific_names">{I18n.t( "scientific_name" )}</option>
          </select>
          <label htmlFor="user_place_id">{I18n.t( "views.users.edit.name_place_help_html" )}</label>
          <PlaceAutocomplete
            config={config}
            resetOnChange={false}
            initialPlaceID={profile.place_id}
            bootstrapClear
            afterSelect={e => handlePlaceAutocomplete( e, "place_id" )}
            afterClear={( ) => handlePlaceAutocomplete( { item: { id: 0 } }, "place_id" )}
          />
        </SettingsItem>
        <TaxonNamePreferencesContainer />
        <SettingsItem>
          <h4>{I18n.t( "community_moderation_settings" )}</h4>
          <CheckboxRowContainer
            name="prefers_community_taxa"
            label={I18n.t( "accept_community_identifications" )}
            description={
              I18n.t( "views.users.edit.prefers_community_taxa_desc", { site_name: SITE.short_name || SITE.name } )
            }
          />
          <label htmlFor="preferred_observation_fields_by">{I18n.t( "who_can_add_observation_fields_to_my_obs" )}</label>
          <p className="text-muted">{I18n.t( "observation_fields_by_preferences_description" )}</p>
          <select
            className="form-control dropdown"
            id="preferred_observation_fields_by"
            value={profile.preferred_observation_fields_by}
            name="preferred_observation_fields_by"
            onChange={handleInputChange}
          >
            {Object.keys( obsFields ).map( value => (
              <option value={value} key={value}>{obsFields[value]}</option>
            ) )}
          </select>
        </SettingsItem>
      </div>
    </div>
  );
};

Content.propTypes = {
  config: PropTypes.object,
  profile: PropTypes.object,
  handleInputChange: PropTypes.func,
  handleCustomDropdownSelect: PropTypes.func,
  handleDisplayNames: PropTypes.func,
  handlePlaceAutocomplete: PropTypes.func,
  showModal: PropTypes.func
};

export default Content;
