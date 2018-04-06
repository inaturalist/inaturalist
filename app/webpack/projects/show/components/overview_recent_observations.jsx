import _ from "lodash";
import React, { Component, PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import Observation from "./observation";

class OverviewRecentObservations extends Component {
  render( ) {
    const { project, config, setSelectedTab } = this.props;
    if ( !project.observations_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    const instances = project.observations.results;
    if ( _.isEmpty( instances ) ) {
      return (
        <Grid>
          <Row>
            <Col xs={ 12 }>
              <div className="no-obs">
                No observations yet. Check back soon!
              </div>
            </Col>
          </Row>
        </Grid>
      );
    }
    return (
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <h2>
              { I18n.t( "recent_observations" ) }
              <i
                className="fa fa-arrow-circle-right"
                onClick={ ( ) => setSelectedTab( "observations" ) }
              />
              <button
                className="btn-green"
                onClick={ ( ) => setSelectedTab( "observations" ) }
              >
                { I18n.t( "view_all" ) }
              </button>
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
    );
  }
}

OverviewRecentObservations.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default OverviewRecentObservations;
