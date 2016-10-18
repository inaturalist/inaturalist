import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import SplitTaxon from "../../../observations/identify/components/split_taxon";
import TaxonAutocomplete from "../../../observations/identify/components/taxon_autocomplete";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import ChartsContainer from "../containers/charts_container";
import Leaders from "../components/leaders";
import TaxonPageTabsContainer from "../containers/taxon_page_tabs_container";
import PlaceChooser from "./place_chooser";
import TaxonCrumbs from "./taxon_crumbs";
import StatusHeader from "./status_header";
import { urlForTaxon } from "../util";

const App = ( { taxon, place, setPlace } ) => (
  <div id="TaxonDetail">
    <Grid>
      <Row className="preheader">
        <Col xs={12}>
          <TaxonCrumbs
            taxon={taxon}
            ancestors={taxon.ancestors}
            url={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}
          />
          <a href={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}>
            <i className="glyphicon glyphicon-link"></i>
          </a>
          <div className="pull-right">
            <TaxonAutocomplete
              inputClassName="input-sm"
              bootstrapClear
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
          <PlaceChooser
            place={place}
            className="pull-right"
            setPlace={setPlace}
            clearPlace={ ( ) => setPlace( null ) }
          />
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
  </div>
);

App.propTypes = {
  taxon: PropTypes.object,
  place: PropTypes.object,
  setPlace: PropTypes.func
};

export default App;
