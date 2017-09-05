import React, { PropTypes } from "react";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";

const ObservationsGridItemForIdentify = ( {
  observation,
  onObservationClick,
  onAgree,
  toggleReviewed
} ) => {
  const agreeButton = (
    <OverlayTrigger
      placement="bottom"
      trigger="hover"
      rootClose
      overlay={
        <Tooltip id={`agree-tooltip-${observation.id}`}>
          { I18n.t( "agree_with_current_taxon" ) }
        </Tooltip>
      }
      container={ $( "#wrapper.bootstrap" ).get( 0 ) }
    >
      <Button
        id={`agree-btn-${observation.id}`}
        bsSize="xs"
        bsStyle={observation.currentUserAgrees ? "success" : "default"}
        disabled={ observation.agreeLoading || !observation.taxon || observation.currentUserAgrees}
        onClick={ function ( ) {
          onAgree( observation );
        } }
      >
        <i className={ observation.agreeLoading ? "fa fa-refresh fa-spin fa-fw" : "fa fa-check" }>
        </i> { _.capitalize( I18n.t( "agree" ) ) }
      </Button>
    </OverlayTrigger>
  );
  const showAgree = observation.taxon && observation.taxon.rank_level <= 10 && observation.taxon.is_active;
  const controls = showAgree ? agreeButton : null;
  const before = (
    <div className={`reviewed-notice ${observation.reviewedByCurrentUser ? "reviewed" : ""}`}>
      <label>
        <input
          type="checkbox"
          checked={ observation.reviewedByCurrentUser }
          onChange={ ( ) => {
            toggleReviewed( observation );
          } }
        /> { I18n.t( observation.reviewedByCurrentUser ? "reviewed" : "mark_as_reviewed" ) }
      </label>
    </div>
  );
  return (
    <ObservationsGridItem
      observation={ observation }
      onObservationClick={ onObservationClick }
      onAgree={ onAgree }
      toggleReviewed={ toggleReviewed }
      before={ before }
      controls={ controls }
      linkTarget="_blank"
    />
  );
};

ObservationsGridItemForIdentify.propTypes = {
  observation: PropTypes.object.isRequired,
  onObservationClick: PropTypes.func,
  onAgree: PropTypes.func,
  toggleReviewed: PropTypes.func
};

export default ObservationsGridItemForIdentify;
