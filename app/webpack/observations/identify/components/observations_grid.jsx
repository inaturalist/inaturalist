import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import ObservationsGridItemForIdentify from "./observations_grid_item_for_identify";

const ObservationsGrid = ( {
  observations,
  onObservationClick,
  toggleReviewed,
  onAgree,
  grid,
  currentUser,
  imageSize
} ) => {
  let noObservationsNotice;
  if ( observations.length === 0 ) {
    noObservationsNotice = (
      <div className="text-center text-muted">
        { I18n.t( "no_matching_observations" ) }
      </div>
    );
  }
  return (
    <Row className={`ObservationsGrid ${grid ? "gridded" : "flowed"} ${imageSize === "large" && "image-size-large"}`}>
      <Col xs={12}>
        { noObservationsNotice }
        { observations.map( observation => (
          <ObservationsGridItemForIdentify
            key={observation.id}
            observation={observation}
            onObservationClick={onObservationClick}
            toggleReviewed={toggleReviewed}
            onAgree={onAgree}
            showMagnifier
            currentUser={currentUser}
            imageSize={imageSize}
          />
        ) ) }
      </Col>
    </Row>
  );
};

Col.propTypes = {
  key: PropTypes.number
};
ObservationsGrid.propTypes = {
  observations: PropTypes.arrayOf(
    PropTypes.object
  ).isRequired,
  onObservationClick: PropTypes.func,
  onAgree: PropTypes.func,
  toggleReviewed: PropTypes.func,
  grid: PropTypes.bool,
  currentUser: PropTypes.object,
  imageSize: PropTypes.string
};

export default ObservationsGrid;
