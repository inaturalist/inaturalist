import React, { PropTypes } from "react";
import { Badge, OverlayTrigger, Popover } from "react-bootstrap";

class EstablishmentMeansBadge extends React.Component {

  render( ) {
    const observation = this.props.observation;
    if ( !observation || !observation.taxon || !observation.taxon.taxon_summary ||
         !observation.taxon.taxon_summary.listed_taxon ) {
      return ( <div /> );
    }
    const lt = observation.taxon.taxon_summary.listed_taxon;
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
  }
}

EstablishmentMeansBadge.propTypes = {
  observation: PropTypes.object,
  placement: PropTypes.string
};

export default EstablishmentMeansBadge;
