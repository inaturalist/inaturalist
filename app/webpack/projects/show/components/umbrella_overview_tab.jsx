import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import UmbrellaLeaderboardContainer from "../containers/umbrella_leaderboard_container";
import UmbrellaMapContainer from "../containers/umbrella_map_container";
import RecentObservationsContainer from "../containers/recent_observations_container";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";
import UmbrellaNews from "./umbrella_news";

const UmbrellaOverviewTab = props => {
  const { project, fetchPosts } = props;
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
      <LazyLoad debounce={false} height={570} offset={100}>
        <UmbrellaMapContainer />
      </LazyLoad>
      <LazyLoad debounce={false} height={120} offset={100}>
        <RecentObservationsContainer />
      </LazyLoad>
      <PhotoModalContainer />
      <LazyLoad
        debounce={false}
        height={90}
        offset={100}
        onContentVisible={fetchPosts}
      >
        <UmbrellaNews {...props} />
      </LazyLoad>
    </div>
  );
};


UmbrellaOverviewTab.propTypes = {
  setConfig: PropTypes.func,
  project: PropTypes.object,
  config: PropTypes.object,
  fetchPosts: PropTypes.func
};

export default UmbrellaOverviewTab;
