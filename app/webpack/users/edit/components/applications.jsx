import React from "react";
// import PropTypes from "prop-types";

import SettingsItem from "./settings_item";

const sampleData = [{
  name: "iNaturalist Android App",
  authorized_date: "March 12, 2013",
  revoke_link: 2
}, {
  name: "iNaturalist iOS App",
  authorized_date: "March 13, 2014",
  revoke_link: 3
}];

const Applications = ( ) => (
  <div className="col-xs-9">
    <div className="row">
      <div className="col-xs-4">
        <SettingsItem header={I18n.t( "inaturalist_applications", { site_name: SITE.name } )} htmlFor="notifications" />
      </div>
      <div className="col-xs-4">
        <label>{I18n.t( "date_authorized" )}</label>
      </div>
    </div>
    {sampleData.map( app => (
      <div className="row row-margin">
        <div className="col-xs-4">
          {app.name}
        </div>
        <div className="col-xs-4">
          {app.authorized_date}
        </div>
        <div className="col-xs-5 col-sm-4">
          <button type="button" className="btn btn-default btn-xs">{I18n.t( "log_out" )}</button>
        </div>
      </div>
    ) )}
    <div className="row">
      <div className="col-xs-4">
        <SettingsItem header={I18n.t( "external_applications" )} htmlFor="external_applications" />
      </div>
      <div className="col-xs-4">
        <label>{I18n.t( "date_authorized" )}</label>
      </div>
    </div>
    {sampleData.map( app => (
      <div className="row row-margin">
        <div className="col-xs-4">
          {app.name}
        </div>
        <div className="col-xs-4">
          {app.authorized_date}
        </div>
        <div className="col-xs-5 col-sm-4">
          <button type="button" className="btn btn-default btn-xs">{I18n.t( "revoke" )}</button>
        </div>
      </div>
    ) )}
  </div>
);

// Applications.propTypes = {
//   profile: PropTypes.object
// };

export default Applications;
