import React from "react";
import { renderToString } from "react-dom/server";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonCrumbsContainer from "../containers/taxon_crumbs_container";
import PlaceChooserContainer from "../containers/place_chooser_container";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PhotoBrowserContainer from "../containers/photo_browser_container";
import PhotoModalContainer from "../containers/photo_modal_container";
import { urlForTaxon } from "../../shared/util";

const App = ( { taxon, config } ) => {
  const taxonHTML = renderToString(
    <SplitTaxon
      taxon={taxon}
      user={config.currentUser}
    />
  );
  return (
    <div id="Photos">
      <Grid>
        <Row className="preheader">
          <Col xs={8}>
            <TaxonCrumbsContainer />
            <a className="permalink" href={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}>
              <i className="icon-link" />
            </a>
          </Col>
          <Col xs={4}>
            <div className="pull-right">
              <TaxonAutocomplete
                inputClassName="input-sm"
                bootstrapClear
                placeholder={I18n.t( "search_species_" )}
                searchExternal={false}
                afterSelect={result => {
                  window.location = urlForTaxon( result.item );
                }}
                position={{ my: "right top", at: "right bottom", collision: "none" }}
                config={config}
              />
            </div>
          </Col>
        </Row>
        <Row id="TaxonHeader">
          <Col xs={12}>
            <div className="inner">
              <h1
                dangerouslySetInnerHTML={
                  { __html: I18n.t( "photos_of_taxon_html", { taxon: taxonHTML } ) }
                }
              />
              <div id="place-chooser-container">
                <PlaceChooserContainer container={$( "#app" ).get( 0 )} clearButton />
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
};

App.propTypes = {
  taxon: PropTypes.object,
  config: PropTypes.object
};

App.defaultProps = {
  config: {}
};

export default App;
