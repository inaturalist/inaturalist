import React from "react";
import PropTypes from "prop-types";
import moment from "moment";

const Applications = ( { showModal, apps } ) => {
  const renderEmptyState = ( ) => (
    <p className="nocontent">
      {I18n.t( "you_have_not_authorized_any_applications" )}
    </p>
  );

  if ( apps.length === 0 ) {
    return renderEmptyState( );
  }

  const iNatApps = apps.filter( app => app.application.official === true );
  // tbd on what the endpoint will return
  const connectedApps = apps.filter( app => app.application.official === "connected" );
  const externalApps = apps.filter( app => app.application.official === false );

  const renderHeader = ( ) => (
    <thead>
      <tr className="hidden-xs">
        <th className="borderless">{I18n.t( "application" )}</th>
        <th className="borderless">{I18n.t( "date_authorized" )}</th>
        <th className="borderless" />
      </tr>
    </thead>
  );

  const renderRow = ( app, buttonText ) => (
    <tr key={app.application.name}>
      <td className="col-xs-4 borderless table-row">{app.application.name}</td>
      <td className="col-xs-4 borderless table-row">{moment( app.created_at ).format( "LL" )}</td>
      <td className="col-xs-4 borderless table-row">
        <button
          type="button"
          className="btn btn-default"
          onClick={( ) => {
            showModal( app.application.id, app.application.name, app.application.official );
          }}
        >
          {buttonText}
        </button>
      </td>
    </tr>
  );

  const createTable = ( appList, buttonText ) => (
    <table className="table">
      {renderHeader( )}
      <tbody className="borderless">
        {appList.map( app => renderRow( app, buttonText ) )}
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
      {connectedApps.length > 0 && (
        <div>
          <h4>{I18n.t( "connected_accounts_titlecase" )}</h4>
          <p className="text-muted app-description-width">{I18n.t( "connected_accounts_description" )}</p>
          {createTable( connectedApps, I18n.t( "disconnect" ) )}
        </div>
      )}
      {externalApps.length > 0 && (
        <div>
          <h4>{I18n.t( "external_applications" )}</h4>
          <p className="text-muted app-description-width">{I18n.t( "external_applications_description" )}</p>
          {createTable( externalApps, I18n.t( "revoke" ) )}
        </div>
      )}
    </div>
  );
};

Applications.propTypes = {
  showModal: PropTypes.func,
  apps: PropTypes.array
};

export default Applications;
