import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import UmbrellaLeaderboardContainer from "../containers/umbrella_leaderboard_container";
import UmbrellaMapContainer from "../containers/umbrella_map_container";
import RecentObservationsContainer from "../containers/recent_observations_container";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";
import UmbrellaNews from "./umbrella_news";

const UmbrellaOverviewTab = props => {
  const { project } = props;
  if ( !project.umbrella_stats_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  return (
    <div className="UmbrellaOverviewTab">
      <Grid>
        <Row>
          <Col xs={12}>
            <UmbrellaLeaderboardContainer />
          </Col>
        </Row>
      </Grid>
      <UmbrellaMapContainer />
      <RecentObservationsContainer />
      <PhotoModalContainer />
      <UmbrellaNews {...props} />
    </div>
  );
};


UmbrellaOverviewTab.propTypes = {
  setConfig: PropTypes.func,
  project: PropTypes.object,
  config: PropTypes.object
};

export default UmbrellaOverviewTab;
