import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import ChartsContainer from "../containers/charts_container";
import Leaders from "../components/leaders";
import TaxonPageTabsContainer from "../containers/taxon_page_tabs_container";
import PhotoModalContainer from "../containers/photo_modal_container";
import PlaceChooserContainer from "../containers/place_chooser_container";
import TaxonCrumbs from "./taxon_crumbs";
import StatusHeader from "./status_header";
import { urlForTaxon } from "../util";

const App = ( { taxon } ) => (
  <div id="TaxonDetail">
    <Grid>
      <Row className="preheader">
        <Col xs={8}>
          <TaxonCrumbs
            taxon={taxon}
            ancestors={taxon.ancestors}
            url={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}
          />
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
          <h1 className="pull-left">
            <SplitTaxon taxon={taxon} />
          </h1>
          <PlaceChooserContainer className="pull-right" />
        </Col>
      </Row>
    </Grid>
    <Grid fluid>
      <Row id="hero">
        <Col xs={12}>
          <Grid>
            <Row>
              <Col xs={12}>
                { taxon.conservationStatus ? <StatusHeader status={taxon.conservationStatus} /> : null }
              </Col>
            </Row>
            <Row>
              <Col xs={6}>
                <PhotoPreviewContainer />
              </Col>
              <Col xs={6}>
                <Leaders taxon={taxon} />
                <Row>
                  <Col xs={12}>
                    <ChartsContainer />
                  </Col>
                </Row>
              </Col>
            </Row>
          </Grid>
        </Col>
      </Row>
    </Grid>
    <TaxonPageTabsContainer />
    <PhotoModalContainer />
  </div>
);

App.propTypes = {
  taxon: PropTypes.object
};

export default App;
