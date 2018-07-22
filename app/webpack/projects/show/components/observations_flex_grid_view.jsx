import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import Observation from "./observation";
import InfiniteScroll from "react-infinite-scroller";

const ObservationsFlexGridView = ( { config, observations, hasMore, loadMore, scrollIndex } ) => {
  if ( _.isEmpty( observations ) ) { return ( <span /> ); }
  const index = scrollIndex || 30;
  const loader = ( <div key="observations-flex-grid-view-loading" className="loading_spinner huge" /> );
  return (
    <div className="ObservationFlexGridView">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <InfiniteScroll
              loadMore={ loadMore }
              hasMore={ hasMore }
              loader={ loader }
            >
              <div className="ObservationsGrid" key="observations-flex-grid">
                { observations.slice( 0, index ).map( o => {
                  let itemDim = 235;
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
            </InfiniteScroll>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

ObservationsFlexGridView.propTypes = {
  config: PropTypes.object,
  setConfig: PropTypes.func,
  hasMore: PropTypes.bool,
  infiniteScrollObservations: PropTypes.func,
  loadMore: PropTypes.func,
  scrollIndex: PropTypes.number,
  observations: PropTypes.array
};

export default ObservationsFlexGridView;
