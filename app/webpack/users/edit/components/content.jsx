import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";

import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";
import inaturalistjs from "inaturalistjs";

const Content = ( {
  profile,
  setUserData,
  handleInputChange,
  handleCustomDropdownSelect
} ) => {
  const handlePlaceDropdownSelect = ( { item } ) => {
    const updatedProfile = profile;
    updatedProfile.place_id = item.id;
    setUserData( updatedProfile );
  };

  const createRadioButtons = ( ) => ["any", "joined", "none"].map( button => (
    <div>
      <label>
        <input
          id="user_preferred_project_addition_by"
          type="radio"
          value={button}
          name="preferred_project_addition_by"
          checked={profile.preferred_project_addition_by === button}
          onChange={handleInputChange}
        />
        {I18n.t( `views.users.edit.project_addition_preferences.${button}` )}
      </label>
    </div>
  ) );

  const showDefaultLicense = license => {
    const iNatLicenses = iNaturalist.Licenses;
    const selected = Object.keys( iNatLicenses ).find( i => iNatLicenses[i].code === license );
    const defaultLicense = selected || "cc-by-nc";

    const localizedName = defaultLicense === "cc0" ? "cc_0" : defaultLicense.replaceAll( "-", "_" );

    return (
      <span className="inline">
        <img id="image-license" src={iNatLicenses[defaultLicense].icon_large} alt={defaultLicense} />
        <label className="user-prefers-license" htmlFor="image-license">
          {I18n.t( `${localizedName}_name` )}
        </label>
      </span>
    );
  };

  const createLicenseList = name => {
    const iNatLicenses = iNaturalist.Licenses;

    const displayList = ["cc0", "cc-by", "cc-by-nc", "cc-by-nc-nd", "cc-by-nc-sa", "cc-by-nd", "cc-by-sa", "c"];

    const menuItems = displayList.map( license => {
      const localizedName = license === "cc0" ? "cc_0" : license.replaceAll( "-", "_" );
      const { code } = iNatLicenses[license];

      return (
        <MenuItem
          key={`${name}-${license}`}
          eventKey={code}
          className="custom-dropdown-width"
        >
          {license === "c" ? (
            <div>
              <label htmlFor="image-license">{I18n.t( "no_license_all_rights_reserved" )}</label>
              <p
                className="text-muted wrap-white-space"
                // eslint-disable-next-line react/no-danger
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "you_retain_full_copyright", {
                    site_name: SITE.name
                  } )
                }}
              />
              {profile[name] === code && <i className="fa fa-check blue-text align-right" aria-hidden="true" />}
            </div>
          ) : (
            <span className="flex-no-wrap wrap-white-space">
              <img id="image-license" src={iNatLicenses[license].icon_large} alt={license} />
              <label className="user-prefers-license" htmlFor="image-license">{I18n.t( `${localizedName}_name` )}</label>
              {profile[name || "cc-by-nc"] === code && <i className="fa fa-check blue-text align-right" aria-hidden="true" />}
            </span>
          )}
        </MenuItem>
      );
    } );

    const divider = <MenuItem divider />;

    return menuItems.map( ( e, i ) => (
      i < menuItems.length - 1 ? [e, divider] : [e]
    ) ).reduce( ( a, b ) => a.concat( b ) );
  };

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <SettingsItem header={I18n.t( "project_settings" )} htmlFor="user_preferred_project_addition_by">
            <p>
              <label htmlFor="user_preferred_project_addition_by">{I18n.t( "which_projects_can_add_your_observations?" )}</label>
            </p>
            {createRadioButtons( )}
            <p className="text-muted">{I18n.t( "views.users.edit.project_settings_desc" )}</p>
            <p
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.this_only_applies_to_traditional_projects", {
                  url: "https://www.inaturalist.org/blog/15450-announcing-changes-to-projects-on-inaturalist"
                } )
              }}
            />
          </SettingsItem>
          <SettingsItem header={I18n.t( "taxonomy_settings" )} htmlFor="user_prefers_automatic_taxonomic_changes">
            <CheckboxRowContainer
              name="prefers_automatic_taxon_changes"
              label={I18n.t( "automatically_update_my_content_for_taxon_changes" )}
              id="user_prefers_automatic_taxonomic_changes"
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
          <SettingsItem header={I18n.t( "licensing" )} htmlFor="about_licenses">
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
              <a href="#" id="about_licenses">{I18n.t( "learn_what_these_licenses_mean" )}</a>
            </p>
            <label htmlFor="preferred_observation_license">{I18n.t( "default_observation_license" )}</label>
            <div>
              <DropdownButton
                id="preferred_observation_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_observation_license" )}
                className="custom-dropdown-width"
                title={showDefaultLicense( profile.preferred_observation_license )}
              >
                {createLicenseList( "preferred_observation_license" )}
              </DropdownButton>
            </div>
            <CheckboxRowContainer
              name="make_observation_licenses_same"
              label={I18n.t( "update_existing_observations_with_new_license" )}
              id="user_make_observation_licenses_same"
            />
            <label htmlFor="preferred_photo_license">{I18n.t( "default_photo_license" )}</label>
            <div>
              <DropdownButton
                id="preferred_photo_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_photo_license" )}
                className="custom-dropdown-width"
                title={showDefaultLicense( profile.preferred_photo_license )}
              >
                {createLicenseList( "preferred_photo_license" )}
              </DropdownButton>
            </div>
            <CheckboxRowContainer
              name="make_photo_licenses_same"
              label={I18n.t( "update_existing_photos_with_new_license" )}
              id="user_make_photo_licenses_same"
            />
            <label htmlFor="preferred_sound_license">{I18n.t( "default_sound_license" )}</label>
            <div>
              <DropdownButton
                id="preferred_sound_license"
                onSelect={e => handleCustomDropdownSelect( e, "preferred_sound_license" )}
                className="custom-dropdown-width"
                title={showDefaultLicense( profile.preferred_sound_license )}
              >
                {createLicenseList( "preferred_sound_license" )}
              </DropdownButton>
            </div>
            <CheckboxRowContainer
              name="make_sound_licenses_same"
              label={I18n.t( "update_existing_sounds_with_new_license" )}
              id="user_make_sound_licenses_same"
            />
          </SettingsItem>
        </div>
        <div className="col-md-1" />
        <div className="col-md-6 col-xs-10">
          <SettingsItem header={I18n.t( "names" )} htmlFor="user_prefers_common_names">
            <p>
              <label htmlFor="user_prefers_common_names">{I18n.t( "display" )}</label>
            </p>
            <div className="text-muted">{I18n.t( "this_is_how_taxon_names_will_be_displayed", { site_name: SITE.name } )}</div>
            <select
              className="form-control"
              id="user_prefers_common_names"
              name="prefers_common_names"
              onChange={handleInputChange}
            >
              <option value="prefers_common_names">{`${I18n.t( "common_name" )} (${I18n.t( "scientific_name" )})`}</option>
              <option value="prefers_scientific_name_first">{`${I18n.t( "scientific_name" )} (${I18n.t( "common_name" )})`}</option>
              <option value="prefers_scientific_names">{I18n.t( "scientific_name" )}</option>
            </select>
            <div>
              <label htmlFor="user_place_id">{I18n.t( "views.users.edit.name_place_help_html" )}</label>
              <PlaceAutocomplete
                // no id here
                resetOnChange={false}
                initialPlaceID={profile.place_id}
                bootstrapClear
                afterSelect={handlePlaceDropdownSelect}
              />
            </div>
          </SettingsItem>
          <SettingsItem header={I18n.t( "community_moderation_settings" )} htmlFor="user_prefers_community_taxa">
            <CheckboxRowContainer
              name="prefers_community_taxa"
              label={I18n.t( "accept_community_identifications" )}
              id="user_prefers_community_taxa"
              description={(
                <div className="text-muted">
                  {I18n.t( "views.users.edit.prefers_community_taxa_desc", { site_name: SITE.short_name || SITE.name } )}
                </div>
              )}
            />
            <label htmlFor="preferred_observation_fields_by">{I18n.t( "who_can_add_observation_fields_to_my_obs" )}</label>
            <div className="text-muted">{I18n.t( "observation_fields_by_preferences_description" )}</div>
            <select
              className="form-control"
              id="preferred_observation_fields_by"
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
  handleInputChange: PropTypes.func,
  handleCustomDropdownSelect: PropTypes.func
};

export default Content;
