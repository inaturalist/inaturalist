import React, { PropTypes } from "react";

const EstablishmentHeader = ( { establishmentMeans } ) => {
  if ( establishmentMeans.establishment_means === "endemic" ) {
    return (
      <div className="alert establishment-endemic EstablishmentHeader">
        <i className="glyphicon glyphicon-star">
        </i> <strong>
          { I18n.t( "endemic_to_x", { x: establishmentMeans.place.display_name } ) }
        </strong>
      </div>
    );
  }
  return (
    <div className="alert establishment-introduced EstablishmentHeader">
      <i className="glyphicon glyphicon-alert">
      </i> <strong>
        { I18n.t( "introduced_in_place", { place: establishmentMeans.place.display_name } ) }
      </strong>
    </div>
  );
};

EstablishmentHeader.propTypes = {
  establishmentMeans: PropTypes.object
};

export default EstablishmentHeader;
