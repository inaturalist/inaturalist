import React from "react";
import StatusHeader from "./status_header";
import EstablishmentHeaderContainer from "../containers/establishment_header_container";

interface Props {
  conservationStatus?: object | null;
  establishmentMeans?: object | null;
}

const StatusRow = ( { conservationStatus, establishmentMeans }: Props ) => {
  if ( !conservationStatus && !establishmentMeans ) return null;
  return (
    <div className="status-row">
      { conservationStatus && (
        <div className="status-row-item">
          <StatusHeader status={conservationStatus} />
        </div>
      ) }
      { establishmentMeans && (
        <div className="status-row-item">
          <EstablishmentHeaderContainer />
        </div>
      ) }
    </div>
  );
};

export default StatusRow;
