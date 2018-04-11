import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import RecentObservationsContainer from "../containers/recent_observations_container";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";

const ObservationsMapView = ( { project } ) => {
  const totalBounds = project.recent_observations && project.recent_observations.total_bounds;
  return (
    <div className="ObservationsListView">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <TaxonMap
              observationLayers={ [project.search_params] }
              showAccuracy
              enableShowAllLayer={ false }
              clickable={ false }
              scrollwheel={ false }
              overlayMenu={ false }
              mapTypeControl
              mapTypeControlOptions={{
                style: google.maps.MapTypeControlStyle.DROPDOWN_MENU,
                position: google.maps.ControlPosition.TOP_LEFT
              }}
              zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
              minZoom={ 1 }
              maxX={ totalBounds && totalBounds.nelng }
              maxY={ totalBounds && totalBounds.nelat }
              minX={ totalBounds && totalBounds.swlng }
              minY={ totalBounds && totalBounds.swlat }
            />
          </Col>
        </Row>
      </Grid>
      <RecentObservationsContainer />
      <PhotoModalContainer />
    </div>
  );
};

ObservationsMapView.propTypes = {
  project: PropTypes.object
};

export default ObservationsMapView;
