import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";

const EventCountdown = ( { project, setSelectedTab } ) => {
  if ( !project.durationToEvent ) { return ( <span /> ); }
  return (
    <div className="EventCountdown">
      <div className="section-intro">This bioblitz begins in:</div>
      <Row className="">
        <Col xs={ 3 }>
          <span className="value">
            { project.durationToEvent.days( ) }
          </span>
          <span className="type">
            DAYS
          </span>
        </Col>
        <Col xs={ 3 }>
          <span className="value">
            { project.durationToEvent.hours( ) }
          </span>
          <span className="type">
            HOURS
          </span>
        </Col>
        <Col xs={ 3 }>
          <span className="value">
            { project.durationToEvent.minutes( ) }
          </span>
          <span className="type">
            MIN
          </span>
        </Col>
        <Col xs={ 3 }>
          <span className="value">
            { project.durationToEvent.seconds( ) }
          </span>
          <span className="type">
            SEC
          </span>
        </Col>
      </Row>
      <button className="btn-green" onClick={ ( ) => setSelectedTab( "about" ) }>
        About this BioBlitz
      </button>
    </div>
  );
};

EventCountdown.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default EventCountdown;
