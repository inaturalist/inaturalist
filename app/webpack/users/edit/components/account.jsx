import React from "react";
import PropTypes from "prop-types";
import moment from "moment-timezone";
import { MenuItem, DropdownButton } from "react-bootstrap";

const Account = ( { profile, setUserData } ) => {
  const handleInputChange = e => {
    console.log( e, "input change locale" );
    const updatedProfile = profile;
    updatedProfile[e.target.name] = e.target.value;
    setUserData( updatedProfile );
  };

  const createTimeZoneList = ( ) => {
    const options = [<option value="current-timezone">{moment.tz.guess( ).toString( )}</option>];

    return options;
  };

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

  const createINatAffiliationList = ( ) => {
    const pngAssetList = [2, 6, 8, 13, 14, 18];

    return [1, 2, 3, 5, 6, 8, 9, 13, 14, 15, 16, 18, 20].map( number => (
      <MenuItem eventKey={number} key={`inat-affiliation-logo-${number}`}>
        <img
          className="logo-height-width"
          alt={`inat-affiliation-logo-${number}`}
          src={`https://static.inaturalist.org/sites/${number}-logo.${pngAssetList.includes( number ) ? "png" : "svg"}`}
        />
      </MenuItem>
    ) );
  };

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "place_geo.geo_planet_place_types.Time_Zone" )}</h5>
            <div className="account-subheader-text">{I18n.t( "all_your_observations_will_default_this_time_zone" )}</div>
            <select>
              {createTimeZoneList( )}
            </select>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "language_slash_locale" )}</h5>
            <div className="account-subheader-text">{I18n.t( "language_slash_locale_description" )}</div>
            <select name="locale" onChange={handleInputChange}>
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
                  value={profile ? profile.prefers_no_tracking : ""}
                  name="prefers_no_tracking"
                  onChange={handleInputChange}
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
              title={(
                <span>
                  <img
                    className="logo-height-width"
                    alt="inat-affiliation-logo-1"
                    src="https://static.inaturalist.org/sites/1-logo.svg"
                  />
                </span>
              )}
            >
              {createINatAffiliationList( )}
            </DropdownButton>
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
