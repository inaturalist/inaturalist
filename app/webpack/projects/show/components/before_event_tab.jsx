import React, { Component, PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import News from "./news";
import Requirements from "./requirements";
import EventCountdown from "./event_countdown";

class BeforeEventTab extends Component {
  render( ) {
    const { project, setSelectedTab } = this.props;
    if ( !project.observations_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    return (
      <div className="OverviewTab">
        <Grid className="info-grid">
          <Row>
            <Col xs={ 4 }>
              <h2>
                Status
              </h2>
              <EventCountdown { ...this.props } />
            </Col>
            <Col xs={ 4 }>
              <h2>
                Project Requirements
                <i
                  className="fa fa-arrow-circle-right"
                  onClick={ ( ) => setSelectedTab( "about" ) }
                />
              </h2>
              <div className="section-intro">
                Observations in this project must meet the following criteria:
              </div>
              <Requirements { ...this.props } />
            </Col>
            <Col xs={ 4 }>
              <News { ...this.props } />
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
}

BeforeEventTab.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default BeforeEventTab;
