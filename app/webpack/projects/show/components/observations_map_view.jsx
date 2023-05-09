import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import RecentObservationsContainer from "../containers/recent_observations_container";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";

const ObservationsMapView = ( { project, config, updateCurrentUser } ) => {
  const totalBounds = project.recent_observations && project.recent_observations.total_bounds;
  return (
    <div className="ObservationsListView">
      <Grid>
        <Row>
          <Col xs={12}>
            <TaxonMap
              placement="projects-show-observations"
              observationLayers={[Object.assign( { captive: "any" }, project.search_params, { color: "iconic" } )]}
              showAccuracy
              enableShowAllLayer={false}
              overlayMenu={false}
              gestureHandling="auto"
              placeLayers={_.isEmpty( project.placeRules ) ? null : [{
                place: {
                  id: _.map( project.placeRules, "operand_id" ).join( "," ),
                  name: "Places"
                }
              }]}
              minZoom={2}
              maxX={totalBounds && totalBounds.nelng}
              maxY={totalBounds && totalBounds.nelat}
              minX={totalBounds && totalBounds.swlng}
              minY={totalBounds && totalBounds.swlat}
              currentUser={config.currentUser}
              updateCurrentUser={updateCurrentUser}
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
  project: PropTypes.object,
  config: PropTypes.object,
  updateCurrentUser: PropTypes.func
};

export default ObservationsMapView;
