import React from "react";
import PropTypes from "prop-types";
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
  toggleReviewed,
  currentUser,
  imageSize
} ) => {
  const agreeButton = (
    <OverlayTrigger
      placement="bottom"
      trigger={["hover", "focus"]}
      rootClose
      overlay={(
        <Tooltip id={`agree-tooltip-${observation.id}`}>
          { I18n.t( "agree_with_current_taxon" ) }
        </Tooltip>
      )}
      container={$( "#wrapper.bootstrap" ).get( 0 )}
    >
      <Button
        id={`agree-btn-${observation.id}`}
        bsSize="xs"
        bsStyle={observation.currentUserAgrees ? "success" : "default"}
        disabled={observation.agreeLoading || !observation.taxon || observation.currentUserAgrees}
        onClick={( ) => onAgree( observation )}
      >
        <i className={observation.agreeLoading ? "fa fa-refresh fa-spin fa-fw" : "fa fa-check"} />
        { " " }
        { I18n.t( "agree_" ) }
      </Button>
    </OverlayTrigger>
  );
  let showAgree = observation.taxon
    && observation.taxon.rank_level <= 10
    && observation.user
    && observation.user.id !== currentUser.id
    && observation.taxon.is_active;
  if ( currentUser && observation.user && currentUser.id === observation.user.id ) {
    showAgree = false;
  }
  const controls = (
    <div>
      { showAgree && agreeButton }
      { ( observation.identifications_count && observation.identifications_count > 0 ) ? (
        <span className="pull-right identifications-count">
          <i className="icon-identification" />
          { " " }
          { observation.identifications_count }
        </span>
      ) : null }
      { ( observation.comments_count && observation.comments_count > 0 ) ? (
        <span className="pull-right comments-count">
          <i className="icon-chatbubble" />
          { " " }
          { observation.comments_count }
        </span>
      ) : null }
    </div>
  );
  const before = (
    <div className={`reviewed-notice ${observation.reviewedByCurrentUser ? "reviewed" : ""}`}>
      <label>
        <input
          type="checkbox"
          key={`review-checkbox-${observation.id}-${observation.reviewedByCurrentUser}`}
          defaultChecked={observation.reviewedByCurrentUser}
          onChange={( ) => {
            toggleReviewed( observation );
          }}
        />
        { " " }
        { I18n.t( observation.reviewedByCurrentUser ? "reviewed" : "mark_as_reviewed" ) }
      </label>
    </div>
  );
  return (
    <ObservationsGridItem
      observation={observation}
      onObservationClick={onObservationClick}
      onAgree={onAgree}
      toggleReviewed={toggleReviewed}
      before={before}
      controls={controls}
      linkTarget="_blank"
      user={currentUser}
      splitTaxonOptions={{ noParens: true }}
      showAllPhotosPreview
      photoSize={imageSize === "large" ? "medium" : "small"}
    />
  );
};

ObservationsGridItemForIdentify.propTypes = {
  observation: PropTypes.object.isRequired,
  onObservationClick: PropTypes.func,
  onAgree: PropTypes.func,
  toggleReviewed: PropTypes.func,
  currentUser: PropTypes.object,
  imageSize: PropTypes.string
};

export default ObservationsGridItemForIdentify;
