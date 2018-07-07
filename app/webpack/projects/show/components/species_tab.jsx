import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";
import InfiniteScroll from "react-infinite-scroller";

const SpeciesTab = ( { project, config, species, setConfig } ) => {
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
                <div className="result" key={ `grid_taxon_${s.taxon.id}` }>
                  <TaxonThumbnail
                    taxon={ s.taxon }
                    config={ config }
                    truncate={ null }
                    height={ 210 }
                    noInactive
                    overlay={ (
                      <div>
                        <a href={ `/observations?project_id=${project.id}&taxon_id=${s.taxon.id}&place_id=any&verifiable=any` }>
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
  setConfig: PropTypes.func,
  species: PropTypes.array
};

export default SpeciesTab;
