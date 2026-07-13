import React from "react";
import StatusHeader from "./status_header";
import EstablishmentHeaderContainer from "../containers/establishment_header_container";

interface Props {
  conservationStatus?: object | null;
  establishmentMeans?: object | null;
}

const StatusRow = ( { conservationStatus, establishmentMeans }: Props ) => {
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

export default StatusRow;
