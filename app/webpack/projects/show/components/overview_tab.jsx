import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import RecentObservationsContainer from "../containers/recent_observations_container";
import TopObserversPanelContainer from "../containers/top_observers_panel_container";
import TopSpeciesObserversPanelContainer from "../containers/top_species_observers_panel_container";
import TopSpeciesPanelContainer from "../containers/top_species_panel_container";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";
import Observation from "./observation";

const OverviewTab = ( { project, config } ) => {
  const instances = project.observations_loaded ? project.observations.results : [];
  if ( _.isEmpty( instances ) ) { return ( <span /> ); }
  return (
    <div className="Overview">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <h2>Recent Observations</h2>
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
      <Grid>
        <Row>
          <Col xs={ 12 }>
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
  );
};

OverviewTab.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object
};

export default OverviewTab;
