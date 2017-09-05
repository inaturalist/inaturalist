import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";
import TopObserverContainer from "../containers/top_observer_container";
import TopIdentifierContainer from "../containers/top_identifier_container";
import NumSpeciesContainer from "../containers/num_species_container";
import LastObservationContainer from "../containers/last_observation_container";
import NumObservationsContainer from "../containers/num_observations_container";

const Leaders = ( { taxon } ) => {
  let optional = <NumObservationsContainer />;
  if ( taxon.rank_level > 10 ) {
    if ( taxon.complete_species_count ) {
      optional = <NumSpeciesContainer />;
    } else {
      optional = <LastObservationContainer />;
    }
  }
  return (
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
          { optional }
        </Col>
        <Col xs={6}>
          <NumObservationsContainer />
        </Col>
      </Row>
    </div>
  );
};

Leaders.propTypes = {
  taxon: PropTypes.object
};

export default Leaders;
