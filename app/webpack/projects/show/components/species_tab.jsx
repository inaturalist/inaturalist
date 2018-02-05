import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";
import InfiniteScroll from "react-infinite-scroller";

const SpeciesTab = ( { config, species, setConfig } ) => {
  if ( _.isEmpty( species ) ) { return ( <span /> ); }
  const loader = ( <div className="loading_spinner huge" /> );
  const scrollIndex = config.speciesScrollIndex || 30;
  return (
    <div className="TopSpecies">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <InfiniteScroll
              loadMore={ ( ) => { setConfig( { speciesScrollIndex: scrollIndex + 30 } ); } }
              hasMore={ species.length >= scrollIndex }
              loader={ loader }
              className="results"
            >
              { _.map( species.slice( 0, scrollIndex ), s => (
                <div className="result">
                  <TaxonThumbnail
                    taxon={ s.taxon }
                    config={ config }
                    truncate={ null }
                    overlay={ (
                      <div>
                        { I18n.t( "x_observations", { count: s.count } ) }
                      </div>
                    )}
                  />
                </div>
              ) ) }
            </InfiniteScroll>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

SpeciesTab.propTypes = {
  config: PropTypes.object,
  setConfig: PropTypes.func,
  species: PropTypes.array
};

export default SpeciesTab;
