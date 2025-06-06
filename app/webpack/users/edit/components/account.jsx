import React from "react";
import PropTypes from "prop-types";
import { MenuItem, DropdownButton } from "react-bootstrap";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

/* global TIMEZONES */

const Account = ( {
  config,
  handleCustomDropdownSelect,
  handleInputChange,
  handlePlaceAutocomplete,
  sites,
  userSettings
} ) => {
  if ( !sites ) { return null; }
  const siteId = userSettings.site_id || 1;
  const currentNetworkAffiliation = sites.filter( site => site.id === siteId )[0];

  // these locales are not available for all regions (like "en-US")
  // so taking the list of keys from the english version
  const localeListKeys = Object.keys( I18n.t( "locales", { locale: "en" } ) );

  const setLocale = ( ) => {
    let { locale } = userSettings;
    locale = locale || I18n.locale;
    if ( localeListKeys.includes( locale ) ) {
      return locale;
    }
    // this provides fallbacks with users for unsupported locales, like "en-US"
    const twoLetterLanguageCode = locale.split( "-" )[0];
    return localeListKeys.includes( twoLetterLanguageCode ) ? twoLetterLanguageCode : "en";
  };

  const localeList = Object.keys( I18n.t( "locales", { locale: "en" } ) );

  const createTimeZoneList = ( ) => (
    TIMEZONES.map( zone => <option value={zone.value} key={zone.value}>{zone.label}</option> )
  );

  const createLocaleList = ( ) => localeList.map( locale => (
    <option value={locale} key={locale}>
      {I18n.t( `locales.${locale}`, { locale } )}
    </option>
  ) );

  const showNetworkLogo = ( id, logo ) => <img className="network-logo" alt={`inat-affiliation-logo-${id}`} src={logo} />;

  const showCurrentNetwork = ( ) => (
    <div className="current-network">
      {showNetworkLogo( siteId, currentNetworkAffiliation.icon_url )}
      <div className="text-muted current-network-name">
        {currentNetworkAffiliation.name}
      </div>
      <div className="caret" />
    </div>
  );

  const thirdPartyTrackingModalDescription = (
    <div>
      <p>
        <strong>
          {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_we_use" )}
        </strong>
      </p>
      <ul>
        <li>
          <strong>
            <span
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.prefers_no_tracking_label_desc_we_use_google_html" )
              }}
            />
          </strong>
        </li>
        <li className="stacked">
          <strong>
            <a href="https://newrelic.com/">New Relic</a>
          </strong>
        </li>
      </ul>
      <p>
        <strong>
          {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share" )}
        </strong>
      </p>
      <ul>
        <li
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html:
              I18n.t(
                "views.users.edit.prefers_no_tracking_label_desc_info_we_share_ip_addresses_html"
              )
          }}
        />
        <li>
          {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_browser_details" )}
        </li>
        <li>
          {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_crash_details" )}
        </li>
        <li>
          {I18n.t( "views.users.edit.prefers_no_tracking_label_desc_info_we_share_device_details" )}
        </li>
        <li
          className="stacked"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.users.edit.prefers_no_tracking_label_desc_value_html" )
          }}
        />
      </ul>
      <p>{I18n.t( "views.users.edit.prefers_no_tracking_label_desc_limits" )}</p>
    </div>
  );

  return (
    <>
      <div className="row">
        <div className="col-md-5 col-sm-10">
          <h4>{I18n.t( "account" )}</h4>
          <SettingsItem header={I18n.t( "language_slash_locale" )} htmlFor="user_locale">
            <p className="text-muted">{I18n.t( "language_slash_locale_description" )}</p>
            <select id="user_locale" className="form-control dropdown" value={setLocale( )} name="locale" onChange={handleInputChange}>
              {createLocaleList( )}
            </select>
          </SettingsItem>
          <SettingsItem header={I18n.t( "default_search_place" )} htmlFor="user_search_place_id">
            <p className="text-muted">{I18n.t( "default_search_place_description" )}</p>
            <PlaceAutocomplete
              config={config}
              resetOnChange={false}
              initialPlaceID={userSettings.search_place_id}
              bootstrapClear
              afterSelect={e => handlePlaceAutocomplete( e, "search_place_id" )}
              afterClear={( ) => handlePlaceAutocomplete( { item: { id: 0 } }, "search_place_id" )}
            />
          </SettingsItem>
          <SettingsItem header={I18n.t( "activerecord.attributes.user.time_zone" )} htmlFor="user_time_zone">
            <p className="text-muted">{I18n.t( "default_display_time_zone" )}</p>
            <select id="user_time_zone" className="form-control dropdown" value={userSettings.time_zone} name="time_zone" onChange={handleInputChange}>
              {createTimeZoneList( )}
            </select>
          </SettingsItem>
          <SettingsItem header={I18n.t( "privacy" )} htmlFor="user_prefers_no_tracking">
            <CheckboxRowContainer
              name="prefers_no_tracking"
              label={I18n.t( "views.users.edit.prefers_no_tracking_label" )}
              modalDescription={thirdPartyTrackingModalDescription}
              modalDescriptionTitle={I18n.t( "third_party_tracking" )}
              modalClassName="ThirdPartyTrackingModal"
            />
            <CheckboxRowContainer
              name="pi_consent"
              label={I18n.t( "pi_consent_label" )}
              modalDescription={I18n.t( "pi_consent_desc_html", { privacy_url: "/privacy", terms_url: "/terms" } )}
              modalDescriptionTitle={I18n.t( "pi_consent_desc_title" )}
              disabled={userSettings.pi_consent}
              confirm={I18n.t( "revoke_privacy_consent_warning" )}
            />
            <CheckboxRowContainer
              name="data_transfer_consent"
              label={I18n.t( "data_transfer_consent_label" )}
              modalDescription={I18n.t( "data_transfer_consent_desc_html", { privacy_url: "/privacy", terms_url: "/terms" } )}
              modalDescriptionTitle={I18n.t( "data_transfer_consent_desc_title" )}
              disabled={userSettings.data_transfer_consent}
              confirm={I18n.t( "revoke_privacy_consent_warning" )}
            />
          </SettingsItem>
        </div>
        <div className="col-md-5 col-sm-10 col-md-offset-1">
          { currentNetworkAffiliation
            ? (
              <SettingsItem header={I18n.t( "inaturalist_network_affiliation" )} htmlFor="user_site_id">
                <div className="stacked" id="AffiliationList">
                  <DropdownButton
                    id="user_site_id"
                    onSelect={e => handleCustomDropdownSelect( e, "site_id" )}
                    title={showCurrentNetwork( )}
                    noCaret
                  >
                    {sites.map( site => (
                      <MenuItem
                        key={`inat-affiliation-logo-${site.id}`}
                        eventKey={site.id}
                      >
                        {showNetworkLogo( site.id, site.icon_url )}
                        <div className="text-muted">{site.name}</div>
                        {siteId === site.id && <i className="fa fa-check blue-checkmark" aria-hidden="true" />}
                      </MenuItem>
                    ) )}
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
            )
            : <div className="nocontent"><div className="loading_spinner" /></div> }
        </div>
      </div>
      <div className="row">
        <div className="col-xs-12 col-sm-6">
          <SettingsItem>
            <div className="alert alert-danger" role="alert">
              <h5><label htmlFor="user-delete-account">{I18n.t( "danger_zone" )}</label></h5>
              <p>
                <a
                  href="/users/delete"
                  id="user-delete-account"
                  className="btn btn-danger btn-block"
                >
                  {I18n.t( "delete_your_account" )}
                </a>
              </p>
            </div>
          </SettingsItem>
        </div>
      </div>
    </>
  );
};

Account.propTypes = {
  config: PropTypes.object,
  userSettings: PropTypes.object,
  handleCustomDropdownSelect: PropTypes.func,
  handleInputChange: PropTypes.func,
  handlePlaceAutocomplete: PropTypes.func,
  sites: PropTypes.array
};

export default Account;
