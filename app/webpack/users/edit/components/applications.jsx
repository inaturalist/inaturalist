import React from "react";
import PropTypes from "prop-types";
import moment from "moment";
import _ from "lodash";

/* global AUTH_PROVIDER_URLS */
/* global AUTH_PROVIDER_NAMES */

const Applications = ( { showModal, apps, providerApps } ) => {
  // removed empty state, since connected accounts section will always be displayed
  const iNatApps = apps.filter( app => app.application.official === true );
  const externalApps = apps.filter( app => app.application.official === false );

  const createConnectedAppsList = ( ) => {
    const connectedApps = providerApps;
    // app.provider_name is the key in the AUTH_PROVIDER_NAMES key-value pair
    const userAppNames = connectedApps.map( app => app.provider_name );

    // if a user hasn't connected to one of the AUTH_PROVIDER_URLS apps
    // we need to display it under connected apps with an option to connect
    // if an app is already in their provider_authorizations list
    // the user will see an option to disconnect
    _.difference( Object.keys( AUTH_PROVIDER_URLS ), userAppNames ).forEach( appName => {
      if (
        !userAppNames.includes( appName )
        // As of Spring 2023 we can no longer connect to Facebook, so we
        // should not show the option to connect, even though we should show
        // the option to disconnect a pre-existing authorization
        && appName !== "facebook"
      ) {
        connectedApps.push( {
          id: null,
          provider_name: appName,
          created_at: null
        } );
      }
    } );

    return connectedApps;
  };

  const connectedApps = createConnectedAppsList( );

  const renderHeader = ( ) => (
    <thead>
      <tr className="hidden-xs">
        <th className="borderless">{I18n.t( "application" )}</th>
        <th className="borderless">{I18n.t( "date_authorized" )}</th>
        <th className="borderless" />
      </tr>
    </thead>
  );

  const renderRow = ( app, buttonText ) => {
    const { id, name, official } = app.application;

    return (
      <tr key={name}>
        <td className="col-xs-4 borderless table-row">
          <a href={`/oauth/applications/${id}`}>
            {name}
          </a>
        </td>
        <td className="col-xs-4 borderless table-row">{moment( app.created_at ).format( "LL" )}</td>
        <td className="col-xs-4 borderless table-row">
          <button
            type="button"
            className="btn btn-default"
            onClick={( ) => showModal( id, name, official === true ? "official" : "external" )}
          >
            {buttonText}
          </button>
        </td>
      </tr>
    );
  };

  const renderConnectedAppsRow = app => {
    const { id } = app;
    const name = app.provider_name;
    const date = app.created_at ? moment( app.created_at ).format( "LL" ) : null;

    const disconnectButton = (
      <button
        type="button"
        className="btn btn-default"
        onClick={( ) => showModal( id, AUTH_PROVIDER_NAMES[name], "connectedApp" )}
      >
        {I18n.t( "disconnect" )}
      </button>
    );

    const connectForm = (
      <form action={AUTH_PROVIDER_URLS[name]} method="post" target="_blank" rel="nofollow noopener">
        <input
          type="hidden"
          name="authenticity_token"
          value={$( "meta[name=csrf-token]" ).attr( "content" )}
        />
        <button
          type="submit"
          className="btn btn-default"
        >
          {I18n.t( "connect" )}
        </button>
      </form>
    );

    return (
      <tr key={name}>
        <td className="col-xs-4 borderless table-row">{AUTH_PROVIDER_NAMES[name]}</td>
        <td className="col-xs-4 borderless table-row">{date}</td>
        <td className="col-xs-4 borderless table-row">
          {app.created_at ? disconnectButton : connectForm}
        </td>
      </tr>
    );
  };

  const createTable = ( appList, buttonText = null ) => (
    <table className="table">
      {renderHeader( )}
      <tbody className="borderless">
        {buttonText
          ? appList.map( app => renderRow( app, buttonText ) )
          : appList.map( app => renderConnectedAppsRow( app ) )}
      </tbody>
    </table>
  );

  return (
    <div id="ApplicationsTable">
      {iNatApps.length > 0 && (
        <div>
          <h4>{I18n.t( "inaturalist_applications", { site_name: SITE.name } )}</h4>
          {createTable( iNatApps, I18n.t( "log_out" ) )}
        </div>
      )}
      <div>
        <h4>{I18n.t( "connected_accounts_titlecase" )}</h4>
        <p className="text-muted">{I18n.t( "connected_accounts_description" )}</p>
        {createTable( connectedApps )}
      </div>
      {externalApps.length > 0 && (
        <div>
          <h4>{I18n.t( "external_applications" )}</h4>
          <p className="text-muted">{I18n.t( "external_applications_description" )}</p>
          {createTable( externalApps, I18n.t( "revoke" ) )}
        </div>
      )}
    </div>
  );
};

Applications.propTypes = {
  showModal: PropTypes.func,
  apps: PropTypes.array,
  providerApps: PropTypes.array
};

export default Applications;
