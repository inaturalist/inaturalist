import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import Observation from "./observation";

const OverviewRecentObservations = ( {
  config,
  project,
  setSelectedTab
} ) => {
  if ( !project.recent_observations_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  const instances = project.recent_observations.results;
  if ( _.isEmpty( instances ) ) {
    return (
      <Grid>
        <Row>
          <Col xs={12}>
            <div className="no-obs">
              { I18n.t( "no_observations_yet" ) }
              { ". " }
              { I18n.t( "check_back_soon" ) }
            </div>
          </Col>
        </Row>
      </Grid>
    );
  }
  return (
    <Grid>
      <Row>
        <Col xs={12}>
          <h2>
            { I18n.t( "recent_observations_" ) }
            <button
              type="button"
              className="btn btn-nostyle"
              onClick={( ) => setSelectedTab( "observations" )}
            >
              <i className="fa fa-arrow-circle-right" />
            </button>
            <a
              href={`/observations?project_id=${project.slug}&place_id=any&verifiable=any`}
              className="btn btn-primary btn-inat btn-green pull-right"
            >
              { I18n.t( "view_all" ) }
            </a>
          </h2>
          <div className="ObservationsGrid">
            { instances.slice( 0, 4 ).map( o => {
              const itemDim = 170;
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
                  observation={o}
                  width={width}
                  config={config}
                />
              );
            } )
           }
          </div>
        </Col>
      </Row>
    </Grid>
  );
};

OverviewRecentObservations.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default OverviewRecentObservations;
