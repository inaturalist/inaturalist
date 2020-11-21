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
  const externalApps = apps.filter( app => app.application.official === false );

  const renderHeader = headerText => (
    <thead>
      <tr className="hidden-xs">
        <th className="borderless">{headerText}</th>
        <th className="borderless">{I18n.t( "date_authorized" )}</th>
        <th className="borderless" />
      </tr>
    </thead>
  );

  const renderRow = ( app, buttonText ) => (
    <tr key={app.application.name}>
      <td className="col-xs-4 borderless">{app.application.name}</td>
      <td className="col-xs-4 borderless">{moment( app.created_at ).format( "LL" )}</td>
      <td className="col-xs-4 borderless">
        <button
          type="button"
          className="btn btn-default btn-xs"
          onClick={( ) => {
            showModal( app.application.id, app.application.name, app.application.official );
          }}
        >
          {buttonText}
        </button>
      </td>
    </tr>
  );

  const createiNatAppsTable = ( ) => iNatApps.map( app => renderRow( app, I18n.t( "log_out" ) ) );
  const createExternalAppsTable = ( ) => externalApps.map( app => renderRow( app, I18n.t( "revoke" ) ) );

  return (
    <div>
      {iNatApps.length > 0 && (
        <table className="table">
          {renderHeader( I18n.t( "inaturalist_applications", { site_name: SITE.name } ) )}
          <tbody className="borderless">
            {createiNatAppsTable( )}
          </tbody>
        </table>
      )}
      {externalApps.length > 0 && (
        <table className="table">
          {renderHeader( I18n.t( "external_applications" ) )}
          <tbody className="borderless">
            {createExternalAppsTable( )}
          </tbody>
        </table>
      )}
    </div>
  );
};

Applications.propTypes = {
  showModal: PropTypes.func,
  apps: PropTypes.array
};

export default Applications;
