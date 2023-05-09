import React, { Component } from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import moment from "moment-timezone";

class EventCountdown extends Component {
  componentDidMount( ) {
    const { startTimeObject, setAttributes } = this.props;
    let timeDiff;
    const now = moment( );
    if ( startTimeObject ) {
      timeDiff = startTimeObject.diff( now );
    }
    setInterval( ( ) => {
      if ( timeDiff <= 0 ) {
        // trigger a refresh of the overview component now that
        // the event has started
        setAttributes( { started: true } );
      } else {
        // trigger a refresh of this component
        this.forceUpdate( );
      }
    }, 200 );
  }

  render( ) {
    const { startTimeObject, setSelectedTab } = this.props;
    let durationToEvent;
    let timeDiff;
    const now = moment( );
    if ( startTimeObject ) {
      timeDiff = startTimeObject.diff( now );
      durationToEvent = moment.duration( timeDiff );
    }
    if ( !durationToEvent ) { return ( <span /> ); }

    const days = Math.floor( durationToEvent.asDays( ) );
    const hours = durationToEvent.hours( );
    const minutes = durationToEvent.minutes( );
    const seconds = durationToEvent.seconds( );
    return (
      <div className="EventCountdown">
        <div className="section-intro">
          {I18n.t( "this_bioblitz_beings_in" ) }
          :
        </div>
        <Row className="">
          <Col xs={3}>
            <span className="value">{ days }</span>
            <span className="type">
              { I18n.t( "datetime.countdown_x_days", { count: days } ) }
            </span>
          </Col>
          <Col xs={3}>
            <span className="value">{ hours }</span>
            <span className="type">
              { I18n.t( "datetime.countdown_x_hours", { count: hours } ) }
            </span>
          </Col>
          <Col xs={3}>
            <span className="value">{ minutes }</span>
            <span className="type">
              { I18n.t( "datetime.countdown_x_minutes", { count: minutes } ) }
            </span>
          </Col>
          <Col xs={3}>
            <span className="value">{ seconds }</span>
            <span className="type">
              { I18n.t( "datetime.countdown_x_seconds", { count: seconds } ) }
            </span>
          </Col>
        </Row>
        <button
          type="button"
          className="btn-green"
          onClick={( ) => setSelectedTab( "about" )}
        >
          { I18n.t( "about_this_bioblitz" ) }
        </button>
      </div>
    );
  }
}

EventCountdown.propTypes = {
  setAttributes: PropTypes.func,
  startTimeObject: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default EventCountdown;
