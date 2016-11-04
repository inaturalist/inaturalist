import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";
import TopObserverContainer from "../containers/top_observer_container";
import TopIdentifierContainer from "../containers/top_identifier_container";
import TopSpeciesContainer from "../containers/top_species_container";
import FirstObservationContainer from "../containers/first_observation_container";
import NumObservationsContainer from "../containers/num_observations_container";

const Leaders = ( { taxon } ) => (
  <div className="Leaders">
    <Row>
      <Col xs={6}>
        <TopObserverContainer />
      </Col>
      <Col xs={6}>
        <TopIdentifierContainer />
      </Col>
    </Row>
    <Row>
      <Col xs={6}>
        { taxon.rank_level > 10 ? <TopSpeciesContainer /> : <FirstObservationContainer /> }
      </Col>
      <Col xs={6}>
        <NumObservationsContainer />
      </Col>
    </Row>
  </div>
);

Leaders.propTypes = {
  taxon: PropTypes.object
};

export default Leaders;
