import React from "react";
import PropTypes from "prop-types";
import moment from "moment";

import SettingsItem from "./settings_item";

const Applications = ( { showModal, apps = [] } ) => {
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

  const renderHeader = ( headerText, htmlFor ) => (
    <div className="row">
      <div className="col-xs-4">
        <SettingsItem header={headerText} htmlFor={htmlFor} />
      </div>
      <div className="col-xs-4">
        <label>{I18n.t( "date_authorized" )}</label>
      </div>
    </div>
  );

  const renderRow = ( app, buttonText ) => (
    <div className="row settings-item" key={app.application.name}>
      <div className="col-xs-4">{app.application.name}</div>
      <div className="col-xs-4">{moment( app.created_at ).format( "LL" )}</div>
      <div className="col-xs-5 col-sm-4">
        <button
          type="button"
          className="btn btn-default btn-xs"
          onClick={( ) => showModal( app.application.id, app.application.name )}
        >
          {buttonText}
        </button>
      </div>
    </div>
  );

  const createiNatAppsList = ( ) => iNatApps.map( app => renderRow( app, I18n.t( "log_out" ) ) );
  const createExternalAppsList = ( ) => externalApps.map( app => renderRow( app, I18n.t( "revoke" ) ) );

  return (
    <div className="col-xs-9">
      {iNatApps.length > 0 && (
        <div>
          {renderHeader( I18n.t( "inaturalist_applications", { site_name: SITE.name } ), "inaturalist_applications" )}
          {createiNatAppsList( )}
        </div>
      ) }
      {externalApps.length > 0 && (
        <div>
          {renderHeader( I18n.t( "external_applications" ), "external_applications" )}
          {createExternalAppsList( )}
        </div>
      ) }
    </div>
  );
};

Applications.propTypes = {
  showModal: PropTypes.func,
  apps: PropTypes.array
};

export default Applications;
