import React from "react";
import StatusHeader from "./status_header";
import EstablishmentHeaderContainer from "../containers/establishment_header_container";
import taxaShowResponsive from "../responsive";
import StatusRowLegacy from "./status_row_legacy";

interface Props {
  conservationStatus?: object | null;
  establishmentMeans?: object | null;
}

const StatusRowResponsive = ( { conservationStatus, establishmentMeans }: Props ) => {
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

// Renders the pre-WEB-984 layout unless the user is testing responsiveness.
// The legacy module is untyped JS, so its props are asserted to match.
type GateProps = React.ComponentProps<typeof StatusRowResponsive>;
const LegacyFallback = StatusRowLegacy as unknown as React.ComponentType<GateProps>;

/* eslint-disable react/jsx-props-no-spreading */
const StatusRow = ( props: GateProps ) => (
  taxaShowResponsive( )
    ? <StatusRowResponsive {...props} />
    : <LegacyFallback {...props} />
);
/* eslint-enable react/jsx-props-no-spreading */

export default StatusRow;
