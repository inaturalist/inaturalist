import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import TopObserverContainer from "../containers/top_observer_container";
import TopIdentifierContainer from "../containers/top_identifier_container";
import NumSpeciesContainer from "../containers/num_species_container";
import LastObservationContainer from "../containers/last_observation_container";
import NumObservationsContainer from "../containers/num_observations_container";

const Leaders = ( { taxon } ) => {
  let optional = <LastObservationContainer />;
  if ( taxon.rank_level > 10 && taxon.complete_species_count ) {
    optional = <NumSpeciesContainer />;
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
