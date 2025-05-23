import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import LicenseImageRow from "./license_image_row";
import TaxonNamePrioritiesContainer from "../containers/taxon_name_priorities_container";
import FavoriteProjectsContainer from "../containers/favorite_projects_container";

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
  handleInputChange,
  handleCustomDropdownSelect,
  handleDisplayNames,
  showModal,
  userSettings
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
          checked={userSettings.preferred_project_addition_by === button}
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
        {userSettings[name] === code && <i className="fa fa-check blue-checkmark" aria-hidden="true" />}
      </MenuItem>
    );
  } );

  const setDisplayName = ( ) => {
    if ( userSettings.prefers_common_names ) {
      if ( !userSettings.prefers_scientific_name_first ) {
        return "prefers_common_names";
      }
      return "prefers_scientific_name_first";
    }
    return "prefers_scientific_names";
  };

  return (
    <div className="row">
      <div className="col-md-5 col-sm-10">
        <SettingsItem>
          <h4>{I18n.t( "project_settings" )}</h4>
          <fieldset>
            <legend>{I18n.t( "which_projects_can_add_your_observations?" )}</legend>
            {createRadioButtons( )}
            <p className="text-muted">{I18n.t( "views.users.edit.project_settings_desc" )}</p>
            <p
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.this_only_applies_to_traditional_projects2" )
              }}
            />
          </fieldset>
          <fieldset>
            <FavoriteProjectsContainer />
          </fieldset>
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
                title={showDefaultLicense( userSettings.preferred_observation_license )}
                noCaret
              >
                {createLicenseList( "preferred_observation_license" )}
              </DropdownButton>
            </div>
            <div className="stacked">
              <CheckboxRowContainer
                name="make_observation_licenses_same"
                label={I18n.t( "update_existing_observations_with_new_license" )}
                modalDescriptionTitle={I18n.t( "update_existing_observations_with_new_license" )}
                modalDescription={I18n.t( "update_existing_observations_with_new_license_desc" )}
              />
            </div>
            <label htmlFor="preferred_photo_license">{I18n.t( "default_photo_license" )}</label>
            <div className="stacked">
              <DropdownButton
                id="preferred_photo_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_photo_license" )}
                title={showDefaultLicense( userSettings.preferred_photo_license )}
                noCaret
              >
                {createLicenseList( "preferred_photo_license" )}
              </DropdownButton>
            </div>
            <div className="stacked">
              <CheckboxRowContainer
                name="make_photo_licenses_same"
                label={I18n.t( "update_existing_photos_with_new_license" )}
                modalDescriptionTitle={I18n.t( "update_existing_photos_with_new_license" )}
                modalDescription={I18n.t( "update_existing_photos_with_new_license_desc" )}
              />
            </div>
            <label htmlFor="preferred_sound_license">{I18n.t( "default_sound_license" )}</label>
            <div className="stacked">
              <DropdownButton
                id="preferred_sound_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_sound_license" )}
                title={showDefaultLicense( userSettings.preferred_sound_license )}
                noCaret
              >
                {createLicenseList( "preferred_sound_license" )}
              </DropdownButton>
            </div>
          </div>
          <CheckboxRowContainer
            name="make_sound_licenses_same"
            label={I18n.t( "update_existing_sounds_with_new_license" )}
            modalDescriptionTitle={I18n.t( "update_existing_sounds_with_new_license" )}
            modalDescription={I18n.t( "update_existing_sounds_with_new_license_desc" )}
          />
        </SettingsItem>
      </div>
      <div className="col-md-5 col-md-offset-1 col-sm-10">
        <section>
          <h4>{I18n.t( "names" )}</h4>
          <fieldset>
            <label htmlFor="user_prefers_common_names">
              { I18n.t( "views.users.edit.common_scientific_name_display_order" ) }
            </label>
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
          </fieldset>
          <fieldset>
            <TaxonNamePrioritiesContainer />
          </fieldset>
        </section>
        <section>
          <h4>{I18n.t( "community_moderation_settings" )}</h4>
          <fieldset>
            <CheckboxRowContainer
              name="prefers_community_taxa"
              label={I18n.t( "accept_community_identifications" )}
              description={
                I18n.t( "views.users.edit.prefers_community_taxa_desc", { site_name: SITE.short_name || SITE.name } )
              }
            />
          </fieldset>
          <fieldset>
            <label htmlFor="preferred_observation_fields_by">{I18n.t( "who_can_add_observation_fields_to_my_obs" )}</label>
            <p className="text-muted">{I18n.t( "observation_fields_by_preferences_description" )}</p>
            <select
              className="form-control dropdown"
              id="preferred_observation_fields_by"
              value={userSettings.preferred_observation_fields_by}
              name="preferred_observation_fields_by"
              onChange={handleInputChange}
            >
              {Object.keys( obsFields ).map( value => (
                <option value={value} key={value}>{obsFields[value]}</option>
              ) )}
            </select>
          </fieldset>
        </section>
      </div>
    </div>
  );
};

Content.propTypes = {
  handleInputChange: PropTypes.func,
  handleCustomDropdownSelect: PropTypes.func,
  handleDisplayNames: PropTypes.func,
  showModal: PropTypes.func,
  userSettings: PropTypes.object
};

export default Content;
