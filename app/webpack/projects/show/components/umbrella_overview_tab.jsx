import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import UmbrellaLeaderboardContainer from "../containers/umbrella_leaderboard_container";
import UmbrellaMapContainer from "../containers/umbrella_map_container";
import RecentObservationsContainer from "../containers/recent_observations_container";

const UmbrellaOverviewTab = ( { project } ) => {
  if ( !project.umbrella_stats_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  return (
    <div className="UmbrellaOverviewTab">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <UmbrellaLeaderboardContainer />
          </Col>
        </Row>
      </Grid>
      <UmbrellaMapContainer />
      <RecentObservationsContainer />
    </div>
  );
};


UmbrellaOverviewTab.propTypes = {
  setConfig: PropTypes.func,
  project: PropTypes.object,
  config: PropTypes.object
};

export default UmbrellaOverviewTab;
