import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import {
  Tab,
  Tabs
} from "react-bootstrap";
import SplitTaxon from "../../../observations/identify/components/split_taxon";
import TaxonAutocomplete from "../../../observations/identify/components/taxon_autocomplete";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import SeasonalityChartContainer from "../containers/seasonality_chart_container";
import HistoryChartContainer from "../containers/history_chart_container";
import TopObserverContainer from "../containers/top_observer_container";
import TopIdentifierContainer from "../containers/top_identifier_container";
import TopSpeciesContainer from "../containers/top_species_container";
import FirstObserverContainer from "../containers/first_observer_container";
import NumObservationsContainer from "../containers/num_observations_container";
import TaxonPageTabsContainer from "../containers/taxon_page_tabs_container";
import PlaceChooser from "./place_chooser";
import TaxonCrumbs from "./taxon_crumbs";
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
              <Col xs={6}>
                <PhotoPreviewContainer />
              </Col>
              <Col xs={6}>
                <Row>
                  <Col xs={6}>
                    <TopObserverContainer />
                  </Col>
                  <Col xs={6}>
                    <TopIdentifierContainer />
                  </Col>
                </Row>
                <Row>
                  <Col xs={6}>
                    { taxon.rank_level > 10 ? <TopSpeciesContainer /> : <FirstObserverContainer /> }
                  </Col>
                  <Col xs={6}>
                    <NumObservationsContainer />
                  </Col>
                </Row>
                <Row>
                  <Col xs={12}>
                    <Tabs id="charts" defaultActiveKey={101}>
                      <Tab eventKey={101} title="Seasonality">
                        <SeasonalityChartContainer />
                      </Tab>
                      <Tab eventKey={102} title="History" unmountOnExit>
                        <HistoryChartContainer />
                      </Tab>
                    </Tabs>
                  </Col>
                </Row>
              </Col>
            </Row>
          </Grid>
        </Col>
      </Row>
      <Row>
        <Col xs={12}>
          <TaxonPageTabsContainer />
        </Col>
      </Row>
    </Grid>
  </div>
);

App.propTypes = {
  taxon: PropTypes.object,
  place: PropTypes.object,
  setPlace: PropTypes.func
};

export default App;
