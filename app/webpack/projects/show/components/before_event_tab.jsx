import _ from "lodash";
import React, { Component, PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import News from "./news";
import Requirements from "./requirements";
import EventCountdown from "./event_countdown";
import OverviewMap from "./overview_map";

class BeforeEventTab extends Component {
  render( ) {
    const { project } = this.props;
    if ( !project.recent_observations_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    return (
      <div className="OverviewTab">
        <Grid className="info-grid">
          <Row>
            <Col xs={ 4 }>
              <h2>
                { I18n.t( "status" ) }
              </h2>
              <EventCountdown
                { ...this.props }
                startTimeObject={ project.startDate }
              />
            </Col>
            <Col xs={ 4 }>
              <Requirements { ...this.props } includeArrowLink />
            </Col>
            <Col xs={ 4 }>
              <News { ...this.props } />
            </Col>
          </Row>
          { !_.isEmpty( project.placeRules ) && (
            <OverviewMap project={ project } />
          ) }
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
