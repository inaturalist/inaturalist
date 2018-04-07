import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import RecentObservationsContainer from "../containers/recent_observations_container";

const ObservationsMapView = ( { project } ) => {
  return (
    <div className="ObservationsListView">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <TaxonMap
              observationLayers={ [project.search_params] }
              showAccuracy
              enableShowAllLayer={ false }
              overlayMenu={ false }
              clickable={ false }
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
    </div>
  );
};

ObservationsMapView.propTypes = {
  project: PropTypes.object
};

export default ObservationsMapView;
