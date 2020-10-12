import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

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

const Account = ( { profile, setUserData } ) => {
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

  const handleSelect = eventKey => {
    const updatedProfile = profile;
    updatedProfile.site_id = eventKey;
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

  const createINatAffiliationList = ( ) => (
    iNatAffiliationDict.map( ( { number, location } ) => (
      <MenuItem
        key={`inat-affiliation-logo-${number}`}
        eventKey={number}
        className="inat-affiliation-width"
      >
        <span className="row-align-center">
          <img
            className="logo-height-width"
            alt={`inat-affiliation-logo-${number}`}
            src={showINatAffiliationLogo( number )}
          />
          <div className="place-name">{location.toLocaleUpperCase( )}</div>
          {profile.site_id === number && <i className="fa fa-check blue-text align-right" aria-hidden="true" />}
        </span>
        {number !== 20 && <div className="no-divider-margin" />}
      </MenuItem>
    ) )
  );

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "place_geo.geo_planet_place_types.Time_Zone" )}</h5>
            <div className="account-subheader-text">{I18n.t( "all_your_observations_will_default_this_time_zone" )}</div>
            <select value={profile.time_zone} name="time_zone" onChange={handleInputChange}>
              {createTimeZoneList( )}
            </select>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "language_slash_locale" )}</h5>
            <div className="account-subheader-text">{I18n.t( "language_slash_locale_description" )}</div>
            <select value={profile.locale} name="locale" onChange={handleInputChange}>
              {createLocaleList( )}
            </select>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "default_search_place" )}</h5>
            <div className="account-subheader-text">{I18n.t( "default_search_place_description" )}</div>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "privacy" )}</h5>
            <div className="row">
              <div className="col-xs-1">
                <input
                  type="checkbox"
                  className="form-check-input"
                  defaultChecked={profile.prefers_no_tracking}
                  name="prefers_no_tracking"
                  onChange={handleCheckboxChange}
                />
              </div>
              <div className="col-xs-9">
                <label>{I18n.t( "views.users.edit.prefers_no_tracking_label" )}</label>
                <div className="blue-text italic-text">{I18n.t( "learn_about_third_party_tracking" )}</div>
              </div>
            </div>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "danger_zone" )}</h5>
            <button className="btn gray-button" type="button">
              <div className="blue-button-text">{I18n.t( "delete_your_account" )}</div>
            </button>
          </div>
        </div>
        <div className="col-md-1" />
        <div className="col-md-6 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "inaturalist_network_affiliation" )}</h5>
            <DropdownButton
              id="inaturalist-affiliation-network-dropdown"
              onSelect={handleSelect}
              className="inat-affiliation-width-height"
              title={(
                <span>
                  <img
                    className="logo-height-width"
                    alt={`inat-affiliation-logo-${profile.site_id || 1}`}
                    src={showINatAffiliationLogo( profile.site_id )}
                  />
                </span>
              )}
            >
              {createINatAffiliationList( )}
            </DropdownButton>
            <div className="margin-medium" />
            <span
              className="account-subheader-text"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.inaturalist_network_affiliation_desc_html", {
                  url: "https://www.inaturalist.org/sites/network"
                } )
              }}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

Account.propTypes = {
  profile: PropTypes.object,
  setUserData: PropTypes.func
};

export default Account;
