import React from "react";
import PropTypes from "prop-types";
import StatusHeader from "./status_header";
import EstablishmentHeaderContainer from "../containers/establishment_header_container";

const StatusRow = ( { conservationStatus, establishmentMeans } ) => {
  if ( conservationStatus && establishmentMeans ) {
    return (
      <div className="status-row">
        <div className="status-row-item">
          <StatusHeader status={conservationStatus} />
        </div>
        <div className="status-row-item">
          <EstablishmentHeaderContainer />
        </div>
      </div>
    );
  }
  if ( conservationStatus ) {
    return <StatusHeader status={conservationStatus} />;
  }
  if ( establishmentMeans ) {
    return <EstablishmentHeaderContainer />;
  }
  return null;
};

StatusRow.propTypes = {
  conservationStatus: PropTypes.object,
  establishmentMeans: PropTypes.object
};

export default StatusRow;
