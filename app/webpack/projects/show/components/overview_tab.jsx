import _ from "lodash";
import React, { Component, PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import RecentObservationsContainer from "../containers/recent_observations_container";
import TopObserversPanelContainer from "../containers/top_observers_panel_container";
import TopSpeciesObserversPanelContainer from "../containers/top_species_observers_panel_container";
import TopSpeciesPanelContainer from "../containers/top_species_panel_container";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";
import News from "./news";
import Requirements from "./requirements";
import OverviewRecentObservations from "./overview_recent_observations";
import OverviewStats from "./overview_stats";

class OverviewTab extends Component {
  render( ) {
    const { project, setSelectedTab } = this.props;
    if ( !project.observations_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    const instances = project.observations.results;
    return (
      <div className="OverviewTab">
        <OverviewRecentObservations { ...this.props } />
        { !_.isEmpty( project.observations.total_bounds ) && (
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
        ) }
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
        { !_.isEmpty( instances ) && (
          <div>
            <Grid>
              <Row>
                <Col xs={ 12 }>
                  <h2>Map of Observations</h2>
                  <TaxonMap
                    observationLayers={ [project.search_params] }
                    showAccuracy
                    enableShowAllLayer={false}
                    overlayMenu
                    clickable={false}
                    scrollwheel={ false }
                    maxX={ project.observations && project.observations.total_bounds.nelng }
                    maxY={ project.observations && project.observations.total_bounds.nelat }
                    minX={ project.observations && project.observations.total_bounds.swlng }
                    minY={ project.observations && project.observations.total_bounds.swlat }
                  />
                </Col>
              </Row>
            </Grid>
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
