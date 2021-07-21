import React from "react";
import PropTypes from "prop-types";
import { Badge, OverlayTrigger, Popover } from "react-bootstrap";

const ConservationStatusBadge = ( { observation, taxon } ) => {
  let targetTaxon = taxon;
  if ( !targetTaxon ) {
    if ( !observation || !observation.taxon ) {
      return <div />;
    }
    targetTaxon = observation.taxon;
  }
  if ( !targetTaxon.taxon_summary || !targetTaxon.taxon_summary.conservation_status ) {
    return <div />;
  }
  const cs = targetTaxon.taxon_summary.conservation_status;
  const popover = (
    <Popover
      className={`ConservationStatusBadgePopover ${cs.iucn_status}`}
      id={`cs-popover-${cs.id}`}
    >
      <div className="title">
        <span className="bold">
          { I18n.t( "conservation_status" ) }:&nbsp;
          { cs.status_name }
          { ( cs.status && cs.status !== cs.status_name ) ? ` (${cs.status})` : "" }
          { cs.place ? ` in ${cs.place.display_name}` : "" }
          { ` (${cs.authority})` }
        </span>
      </div>
      <div
        className="summary"
        dangerouslySetInnerHTML={{ __html: cs.description }}
      />
    </Popover>
  );
  return (
    <div className="ConservationStatusBadge">
      <OverlayTrigger
        trigger="click"
        rootClose
        overlay={popover}
        placement="bottom"
      >
        <Badge className={`${cs.iucn_status}`}>
          { cs.iucn_status_code }
        </Badge>
      </OverlayTrigger>
    </div>
  );
};

ConservationStatusBadge.propTypes = {
  observation: PropTypes.object,
  taxon: PropTypes.object
};

export default ConservationStatusBadge;
