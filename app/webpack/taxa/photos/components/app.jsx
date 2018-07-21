import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonCrumbsContainer from "../containers/taxon_crumbs_container";
import PlaceChooserContainer from "../containers/place_chooser_container";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PhotoBrowserContainer from "../containers/photo_browser_container";
import PhotoModalContainer from "../containers/photo_modal_container";
import { urlForTaxon } from "../../shared/util";

const App = ( { taxon, config } ) => (
  <div id="Photos">
    <Grid>
      <Row className="preheader">
        <Col xs={8}>
          <TaxonCrumbsContainer />
          <a href={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}>
            <i className="glyphicon glyphicon-link"></i>
          </a>
        </Col>
        <Col xs={4}>
          <div className="pull-right">
            <TaxonAutocomplete
              inputClassName="input-sm"
              bootstrapClear
              placeholder={I18n.t( "search_species_" )}
              searchExternal={false}
              afterSelect={ function ( result ) {
                window.location = urlForTaxon( result.item );
              } }
              position={{ my: "right top", at: "right bottom", collision: "none" }}
            />
          </div>
        </Col>
      </Row>
      <Row id="TaxonHeader">
        <Col xs={12}>
          <div className="inner">
            <h1>
              { I18n.t( "photos_of" ) } <SplitTaxon
                taxon={taxon}
                forceRank={taxon.rank_level > 10 && !taxon.preferred_common_name}
                user={ config.currentUser }
              />
            </h1>
            <div id="place-chooser-container">
              <PlaceChooserContainer container={ $( "#app" ).get( 0 ) } />
            </div>
          </div>
        </Col>
      </Row>
    </Grid>
    <Grid fluid>
      <Row id="hero">
        <Col xs={12}>
          <PhotoBrowserContainer />
        </Col>
      </Row>
    </Grid>
    <PhotoModalContainer />
  </div>
);

App.propTypes = {
  taxon: PropTypes.object,
  config: PropTypes.object
};

App.defaultProps = {
  config: {}
};

export default App;
