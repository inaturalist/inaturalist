import React, { PropTypes } from "react";

const EstablishmentHeader = ( { establishmentMeans, url } ) => {
  if ( establishmentMeans.establishment_means === "endemic" ) {
    return (
      <div className="alert establishment-endemic StatusHeader EstablishmentHeader">
        <i className="glyphicon glyphicon-star">
        </i> <strong>
          { I18n.t( "endemic_to_x", { x: establishmentMeans.place.display_name } ) }
        </strong> { url ? <a href={url}>{ I18n.t( "view_details" ) }</a> : null }
      </div>
    );
  }
  if ( establishmentMeans.establishment_means === "native" ) {
    return (
      <div className="alert establishment-endemic StatusHeader EstablishmentHeader">
        <strong>
          { I18n.t( "native_to_place", { place: establishmentMeans.place.display_name } ) }
        </strong> { url ? <a href={url}>{ I18n.t( "view_details" ) }</a> : null }
      </div>
    );
  }
  if ( establishmentMeans.establishment_means === "introduced" ) {
    return (
      <div className="alert establishment-introduced StatusHeader EstablishmentHeader">
        <i className="glyphicon glyphicon-alert">
        </i> <strong>
          { I18n.t( "introduced_in_place", { place: establishmentMeans.place.display_name } ) }
        </strong> { url ? <a href={url}>{ I18n.t( "view_details" ) }</a> : null }
      </div>
    );
  }
  return <div></div>;
};

EstablishmentHeader.propTypes = {
  establishmentMeans: PropTypes.object,
  url: PropTypes.string
};

export default EstablishmentHeader;
