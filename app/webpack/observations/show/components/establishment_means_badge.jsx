import React from "react";
import PropTypes from "prop-types";
import { Badge, OverlayTrigger, Popover } from "react-bootstrap";

const EstablishmentMeansBadge = ( { observation, taxon } ) => {
  let targetTaxon = taxon;
  if ( !targetTaxon ) {
    if ( !observation || !observation.taxon ) {
      return <div />;
    }
    targetTaxon = observation.taxon;
  }
  if ( !targetTaxon.taxon_summary || !targetTaxon.taxon_summary.listed_taxon ) {
    return <div />;
  }
  const lt = targetTaxon.taxon_summary.listed_taxon;
  const meansType = lt.establishment_means === "introduced" ? "introduced" : "endemic";
  const popover = (
    <Popover
      className={ `EstablishmentMeansBadgePopover ${meansType}` }
      id={ `em-popover-${lt.id}` }
    >
      <span className="bold">
        { lt.establishment_means_label }
        { lt.place ? ` in ${lt.place.display_name}` : "" }
        : { lt.establishment_means_description }
      </span>
    </Popover>
  );
  return (
    <div className="EstablishmentMeansBadge">
      <OverlayTrigger
        trigger="click"
        rootClose
        overlay={ popover }
        placement="bottom"
      >
        <Badge className={ `${meansType}` }>
          { meansType === "introduced" ?
            ( <i className="fa fa-exclamation" /> ) :
            ( <i className="fa fa-star" /> )
          }
        </Badge>
      </OverlayTrigger>
    </div>
  );
};

EstablishmentMeansBadge.propTypes = {
  observation: PropTypes.object,
  taxon: PropTypes.object
};

export default EstablishmentMeansBadge;
