import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import Observation from "./observation";
import InfiniteScroll from "react-infinite-scroller";

const ObservationsTab = ( { config, observations, infiniteScrollObservations } ) => {
  if ( _.isEmpty( observations ) ) { return ( <span /> ); }
  const scrollIndex = config.observationsScrollIndex || 30;
  const loader = ( <div className="loading_spinner huge" /> );
  return (
    <div className="ObservationsTab">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <InfiniteScroll
              loadMore={ ( ) => {
                infiniteScrollObservations( scrollIndex + 30 );
              } }
              hasMore={ observations.length >= scrollIndex && scrollIndex < 200 }
              loader={ loader }
            >
              <div className="ObservationsGrid">
                { observations.slice( 0, scrollIndex ).map( o => {
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

ObservationsTab.propTypes = {
  config: PropTypes.object,
  setConfig: PropTypes.func,
  infiniteScrollObservations: PropTypes.func,
  observations: PropTypes.array
};

export default ObservationsTab;
