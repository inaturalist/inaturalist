import React, { PropTypes } from "react";
import { Badge, OverlayTrigger, Popover } from "react-bootstrap";

class ConservationStatusBadge extends React.Component {

  render( ) {
    const observation = this.props.observation;
    if ( !observation || !observation.taxon || !observation.taxon.taxon_summary ||
         !observation.taxon.taxon_summary.conservation_status ) {
      return ( <div /> );
    }
    const cs = observation.taxon.taxon_summary.conservation_status;
    const popover = (
      <Popover
        className={ `ConservationStatusBadgePopover ${cs.iucn_status}` }
        id={ `cs-popover-${cs.id}` }
      >
        <div className="title">
          <span className="bold">
            Conservation status:&nbsp;
            { cs.status_name }
            { ( cs.status && cs.status !== cs.status_name ) ? ` (${cs.status})` : "" }
            { cs.place ? ` in ${cs.place.display_name}` : "" }
            { ` (${cs.authority})` }
          </span>
        </div>
        <div className="summary">
          { cs.description }
        </div>
      </Popover>
    );
    return (
      <div className="ConservationStatusBadge">
        <OverlayTrigger
          trigger="click"
          rootClose
          overlay={ popover }
          placement="bottom"
        >
          <Badge className={ `${cs.iucn_status}` }>
            { cs.iucn_status_code }
          </Badge>
        </OverlayTrigger>
      </div>
    );
  }
}

ConservationStatusBadge.propTypes = {
  observation: PropTypes.object
};

export default ConservationStatusBadge;
