import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import InfiniteScroll from "react-infinite-scroller";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";

const SpeciesTab = ( {
  project,
  config,
  species,
  infiniteScrollSpecies
} ) => {
  if ( _.isEmpty( species ) ) { return ( <span /> ); }
  const loader = <div key="species-tab-loading-spinner" className="loading_spinner huge" />;
  const scrollIndex = config.speciesScrollIndex || 30;
  return (
    <div className="TopSpecies">
      <Grid>
        <Row>
          <Col xs={12}>
            <InfiniteScroll
              loadMore={( ) => {
                infiniteScrollSpecies( scrollIndex, scrollIndex + 30 );
              }}
              hasMore={species.length >= scrollIndex}
              loader={loader}
              className="results d-flex flex-wrap"
            >
              { _.map( species.slice( 0, scrollIndex ), s => (
                <div className="result d-flex" key={`grid_taxon_${s.taxon.id}`}>
                  <TaxonThumbnail
                    className="flex-grow-1"
                    taxon={s.taxon}
                    config={config}
                    height={210}
                    noInactive
                    overlay={(
                      <div>
                        <a href={`/observations?project_id=${project.id}&taxon_id=${s.taxon.id}&place_id=any&verifiable=any`}>
                          { I18n.t( "x_observations", { count: s.count } ) }
                        </a>
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
  project: PropTypes.object,
  config: PropTypes.object,
  infiniteScrollSpecies: PropTypes.func,
  species: PropTypes.array
};

export default SpeciesTab;
