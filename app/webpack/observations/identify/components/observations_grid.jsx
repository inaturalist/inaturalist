import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";
import ObservationsGridItem from "./observations_grid_item";

const ObservationsGrid = ( {
  observations,
  onObservationClick,
  toggleReviewed,
  onAgree,
  grid
} ) => (
  <Row className={`ObservationsGrid ${grid ? "gridded" : "flowed"}`}>
    <Col xs={12}>
      {observations.map( ( observation ) => (
        <ObservationsGridItem
          key={observation.id}
          observation={observation}
          onObservationClick={onObservationClick}
          toggleReviewed={toggleReviewed}
          onAgree={onAgree}
        />
      ) ) }
    </Col>
  </Row>
);

Col.propTypes = {
  key: PropTypes.number
};
ObservationsGrid.propTypes = {
  observations: PropTypes.arrayOf(
    React.PropTypes.object
  ).isRequired,
  onObservationClick: PropTypes.func,
  onAgree: PropTypes.func,
  toggleReviewed: PropTypes.func,
  grid: PropTypes.bool
};

export default ObservationsGrid;
