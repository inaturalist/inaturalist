import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

/* global TIMEZONES */

const iNatAffiliationDict = [
  { number: 1, location: I18n.t( "global" ) },
  { number: 2, location: I18n.t( "places_name.mexico" ) },
  { number: 3, location: I18n.t( "places_name.new_zealand" ) },
  { number: 5, location: I18n.t( "places_name.canada" ) },
  { number: 6, location: I18n.t( "places_name.colombia" ) },
  { number: 8, location: I18n.t( "places_name.portugal" ) },
  { number: 9, location: I18n.t( "places_name.australia" ) },
  { number: 13, location: I18n.t( "places_name.panama" ) },
  { number: 14, location: I18n.t( "places_name.ecuador" ) },
  { number: 15, location: I18n.t( "places_name.italy" ) },
  { number: 16, location: I18n.t( "places_name.argentina" ) },
  { number: 18, location: I18n.t( "places_name.chile" ) },
  { number: 20, location: I18n.t( "places_name.finland" ) }
];

const Account = ( { profile, setUserData, handleInputChange } ) => {
  const handleSelect = eventKey => {
    const updatedProfile = profile;
    updatedProfile.site_id = eventKey;
    setUserData( updatedProfile );
  };

  const fillInputWithSelection = ( { item } ) => {
    const updatedProfile = profile;
    updatedProfile.search_place_id = item.id;
    setUserData( updatedProfile );
  };

  const createTimeZoneList = ( ) => (
    TIMEZONES.map( zone => <option value={zone.value}>{zone.label}</option> )
  );

  const createLocaleList = ( ) => {
    const locales = I18n.t( "locales" );

    const excludeLocalizedName = ["br", "en", "eo", "oc"];

    return Object.keys( locales ).map( locale => (
      <option value={locale} key={locale}>
        {I18n.t( `locales.${locale}` )}
        {!excludeLocalizedName.includes( locale )
          && ` / ${I18n.t( `locales.${locale}`, { locale } )}`}
      </option>
    ) );
  };

  const showINatAffiliationLogo = num => {
    const pngAssetList = [2, 6, 8, 13, 14, 18];
    return `https://static.inaturalist.org/sites/${num}-logo.${pngAssetList.includes( num ) ? "png" : "svg"}`;
  };

  const createINatAffiliationList = ( ) => {
    const divider = <MenuItem divider />;

    const menuItems = iNatAffiliationDict.map( ( { number, location } ) => (
      <MenuItem
        key={`inat-affiliation-logo-${number}`}
        eventKey={number}
        className="inat-affiliation-width"
      >
        <span className="flex-no-wrap">
          <img
            className="inat-affiliation-logo-size"
            alt={`inat-affiliation-logo-${number}`}
            src={showINatAffiliationLogo( number )}
          />
          {location.toLocaleUpperCase( )}
          {profile.site_id === number && <i className="fa fa-check align-right" aria-hidden="true" />}
        </span>
      </MenuItem>
    ) );

    // add a MenuItem divider between all the first and last items
    // using this instead of my own div because it's automatically styled
    // to be the same width as the menu
    return menuItems.map( ( e, i ) => (
      i < menuItems.length - 1 ? [e, divider] : [e]
    ) ).reduce( ( a, b ) => a.concat( b ) );
  };

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <SettingsItem header={I18n.t( "place_geo.geo_planet_place_types.Time_Zone" )} htmlFor="user_time_zone">
            <p className="text-muted">{I18n.t( "all_your_observations_will_default_this_time_zone" )}</p>
            <select id="user_time_zone" className="form-control" value={profile.time_zone} name="time_zone" onChange={handleInputChange}>
              {createTimeZoneList( )}
            </select>
          </SettingsItem>
          <SettingsItem header={I18n.t( "language_slash_locale" )} htmlFor="user_locale">
            <p className="text-muted">{I18n.t( "language_slash_locale_description" )}</p>
            <select id="user_locale" className="form-control" value={profile.locale} name="locale" onChange={handleInputChange}>
              {createLocaleList( )}
            </select>
          </SettingsItem>
          <SettingsItem header={I18n.t( "default_search_place" )} htmlFor="user_search_place_id">
            <div className="text-muted">{I18n.t( "default_search_place_description" )}</div>
            <PlaceAutocomplete
              // can't label this one because PlaceAutocomplete doesn't accept an id in props
              // id="user_search_place_id"
              resetOnChange={false}
              initialPlaceID={profile.search_place_id}
              bootstrapClear
              afterSelect={fillInputWithSelection}
            />
          </SettingsItem>
          <SettingsItem header={I18n.t( "privacy" )} htmlFor="user_prefers_no_tracking">
            <CheckboxRowContainer
              name="prefers_no_tracking"
              label={I18n.t( "views.users.edit.prefers_no_tracking_label" )}
              id="user_prefers_no_tracking"
              description={(
                <p>
                  <a href="#">
                    <i className="fa fa-info-circle" />
                    {` ${I18n.t( "learn_about_third_party_tracking" )}`}
                  </a>
                </p>
              )}
            />
          </SettingsItem>
          <SettingsItem header={I18n.t( "danger_zone" )} htmlFor="user_delete_account">
            <p>
              <a href="#" id="user_delete_account">{I18n.t( "delete_your_account" )}</a>
            </p>
          </SettingsItem>
        </div>
        <div className="col-md-1" />
        <div className="col-md-6 col-xs-10">
          <SettingsItem header={I18n.t( "inaturalist_network_affiliation" )} htmlFor="user_site_id">
            <div>
              <DropdownButton
                id="user_site_id"
                onSelect={handleSelect}
                className="custom-dropdown-width"
                title={(
                  <img
                    className="inat-affiliation-logo-size"
                    alt={`inat-affiliation-logo-${profile.site_id || 1}`}
                    src={showINatAffiliationLogo( profile.site_id )}
                  />
                )}
              >
                {createINatAffiliationList( )}
              </DropdownButton>
            </div>
            <p
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.inaturalist_network_affiliation_desc_html", {
                  url: "https://www.inaturalist.org/sites/network"
                } )
              }}
            />
          </SettingsItem>
        </div>
      </div>
    </div>
  );
};

Account.propTypes = {
  profile: PropTypes.object,
  setUserData: PropTypes.func,
  handleInputChange: PropTypes.func
};

export default Account;
