import _ from "lodash";
import React, { Component, PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
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

class OverviewTab extends Component {
  render( ) {
    const { project } = this.props;
    const instances = project.recent_observations ? project.recent_observations.results : null;
    return (
      <div className="OverviewTab">
        <OverviewRecentObservations { ...this.props } />
        <Grid className="leaders-grid">
          <Row>
            <Col xs={ 4 } className="no-padding">
              <TopObserversPanelContainer />
            </Col>
            <Col xs={ 4 } className="no-padding">
              <TopSpeciesObserversPanelContainer />
            </Col>
            <Col xs={ 4 } className="no-padding">
              <TopSpeciesPanelContainer />
            </Col>
          </Row>
        </Grid>
        <Grid className="info-grid">
          <Row>
            <Col xs={ 4 }>
              <Requirements { ...this.props } includeArrowLink />
            </Col>
            <OverviewStats { ...this.props } />
            <Col xs={ 4 }>
              <News { ...this.props } />
            </Col>
          </Row>
        </Grid>
        { ( !_.isEmpty( project.placeRules ) || !_.isEmpty( instances ) ) && (
          <div>
            <OverviewMap project={ project } />
            <RecentObservationsContainer />
            <PhotoModalContainer />
          </div>
        ) }
      </div>
    );
  }
}

OverviewTab.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default OverviewTab;
