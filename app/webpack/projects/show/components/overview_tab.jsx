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
import IconicTaxaPieChart from "./iconic_taxa_pie_chart";
import Observation from "./observation";

class OverviewTab extends Component {
  render( ) {
    const { project, config, setSelectedTab } = this.props;
    if ( !project.observations_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    const instances = project.observations.results;
    return (
      <div className="OverviewTab">
        { !_.isEmpty( instances ) && (
          <Grid>
            <Row>
              <Col xs={ 12 }>
                <h2>
                  Recent Observations
                  <i
                    className="fa fa-arrow-circle-right"
                    onClick={ ( ) => setSelectedTab( "observations" ) }
                  />
                </h2>
                <div className="ObservationsGrid">
                  { instances.slice( 0, 5 ).map( o => {
                    let itemDim = 170;
                    let width = itemDim;
                    const dims = o.photos.length > 0 && o.photos[0].dimensions( );
                    if ( dims ) {
                      width = itemDim / dims.height * dims.width;
                    } else {
                      width = itemDim;
                    }
                    return (
                      <Observation
                        key={`obs-${o.id}`}
                        observation={ o }
                        width={ width }
                        height={itemDim }
                        config={ config }
                      />
                    );
                  } )
                 }
                </div>
              </Col>
            </Row>
          </Grid>
        ) }
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
              <Requirements { ...this.props } />
            </Col>
            <Col xs={ 4 }>
              <IconicTaxaPieChart { ...this.props } />
            </Col>
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
