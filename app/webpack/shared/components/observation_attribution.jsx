import React from "react";
import PropTypes from "prop-types";

const ObservationAttribution = ( { observation } ) => {
  const { user } = observation;
  const userName = user ? ( user.name || user.login ) : I18n.t( "unknown" );
  const intro = observation.license_code === "cc0"
    ? I18n.t( "by_user", { user: userName } )
    : `\u00A9 ${userName}`;
  if ( !observation.license_code ) {
    return (
      <span>
        { I18n.t( "observation" ) }
        { " " }
        { intro }
        { " " }
        &middot;
        { " " }
        { I18n.t( "all_rights_reserved" ) }
      </span>
    );
  }
  const licenseText = observation.license_code === "cc0"
    ? I18n.t( "copyright.no_rights_reserved" )
    : I18n.t( "some_rights_reserved" );
  return (
    <span className="ObservationAttribution">
      { I18n.t( "observation" ) }
      { " " }
      { intro }
      { " " }
      &middot;
      { " " }
      <a href={iNaturalist.Licenses[observation.license_code].url}>
        { licenseText }
        <img
          src={iNaturalist.Licenses[observation.license_code].icon}
          alt={observation.license_code}
        />
      </a>
    </span>
  );
};

ObservationAttribution.propTypes = {
  observation: PropTypes.object
};

export default ObservationAttribution;
