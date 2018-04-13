import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";

const EventCountdown = ( { project, setSelectedTab } ) => {
  if ( !project.durationToEvent ) { return ( <span /> ); }
  const days = project.durationToEvent.days( );
  const hours = project.durationToEvent.hours( );
  const minutes = project.durationToEvent.minutes( );
  const seconds = project.durationToEvent.seconds( );
  return (
    <div className="EventCountdown">
      <div className="section-intro">
         {I18n.t( "this_bioblitz_beings_in" ) }:
      </div>
      <Row className="">
        <Col xs={ 3 }>
          <span className="value">{ days }</span>
          <span className="type">
            { I18n.t( "datetime.countdown_x_days", { count: days } ) }
          </span>
        </Col>
        <Col xs={ 3 }>
          <span className="value">{ hours }</span>
          <span className="type">
            { I18n.t( "datetime.countdown_x_hours", { count: hours } ) }
          </span>
        </Col>
        <Col xs={ 3 }>
          <span className="value">{ minutes }</span>
          <span className="type">
            { I18n.t( "datetime.countdown_x_minutes", { count: minutes } ) }
          </span>
        </Col>
        <Col xs={ 3 }>
          <span className="value">{ seconds }</span>
          <span className="type">
            { I18n.t( "datetime.countdown_x_seconds", { count: seconds } ) }
          </span>
        </Col>
      </Row>
      <button
        className="btn-green"
        onClick={ ( ) => setSelectedTab( "about" ) }
      >
        { I18n.t( "about_this_bioblitz" ) }
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
