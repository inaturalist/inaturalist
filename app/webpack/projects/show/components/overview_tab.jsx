import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import RecentObservationsContainer from "../containers/recent_observations_container";
import TopObserversPanelContainer from "../containers/top_observers_panel_container";
import TopSpeciesObserversPanelContainer from "../containers/top_species_observers_panel_container";
import TopSpeciesPanelContainer from "../containers/top_species_panel_container";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";
import News from "./news";
import Requirements from "./requirements";
import OverviewRecentObservations from "./overview_recent_observations";
import OverviewStats from "./overview_stats";
import OverviewMap from "./overview_map";

const OverviewTab = props => {
  const {
    config,
    project,
    updateCurrentUser,
    fetchQualityGradeCounts,
    fetchPosts
  } = props;
  const instances = project.recent_observations ? project.recent_observations.results : null;
  return (
    <div className="OverviewTab">
      <LazyLoad
        debounce={false}
        height={229}
        verticalOffset={100}
      >
        <OverviewRecentObservations {...props} />
      </LazyLoad>
      <Grid className="leaders-grid">
        <LazyLoad
          debounce={false}
          height={229}
          verticalOffset={100}
        >
          <Row>
            <Col xs={4} className="no-padding">
              <TopObserversPanelContainer />
            </Col>
            <Col xs={4} className="no-padding">
              <TopSpeciesObserversPanelContainer />
            </Col>
            <Col xs={4} className="no-padding">
              <TopSpeciesPanelContainer />
            </Col>
          </Row>
        </LazyLoad>
      </Grid>
      <Grid className="info-grid">
        <LazyLoad
          debounce={false}
          height={405}
          offset={100}
          onContentVisible={( ) => {
            fetchQualityGradeCounts( );
            fetchPosts( );
          }}
        >
          <Row>
            <Col xs={4}>
              <Requirements {...props} includeArrowLink />
            </Col>
            <OverviewStats {...props} />
            <Col xs={4}>
              <News {...props} />
            </Col>
          </Row>
        </LazyLoad>
      </Grid>
      { ( !_.isEmpty( project.placeRules ) || !_.isEmpty( instances ) ) && (
        <div>
          <LazyLoad debounce={false} height={570} offset={100}>
            <OverviewMap project={project} config={config} updateCurrentUser={updateCurrentUser} />
          </LazyLoad>
          <LazyLoad debounce={false} height={120} offset={100}>
            <RecentObservationsContainer />
          </LazyLoad>
          <PhotoModalContainer />
        </div>
      ) }
    </div>
  );
};

OverviewTab.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func,
  updateCurrentUser: PropTypes.func,
  fetchQualityGradeCounts: PropTypes.func,
  fetchPosts: PropTypes.func
};

export default OverviewTab;
