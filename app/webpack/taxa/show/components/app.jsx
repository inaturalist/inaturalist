import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import {
  Button,
  Tab,
  Tabs
} from "react-bootstrap";
import SplitTaxon from "../../../observations/identify/components/split_taxon";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import SeasonalityChartContainer from "../containers/seasonality_chart_container";
import HistoryChartContainer from "../containers/history_chart_container";
import PlaceChooser from "./place_chooser";
import TaxonCrumbs from "./taxon_crumbs";

const App = ( { taxon, place, setPlace } ) => (
  <div id="TaxonDetail">
    <Grid>
      <Row className="preheader">
        <Col xs={12}>
          <TaxonCrumbs />
          <a href="foo"><i className="fa fa-link"></i></a>
          <Button bsSize="xs" className="pull-right">Search</Button>
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
                  <Col xs={12}>
                    Leaderboards
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
          <Tabs defaultActiveKey={1}>
            <Tab eventKey={1} title="Map">
              Map
            </Tab>
            <Tab eventKey={2} title="Articles">
              Articles
            </Tab>
            <Tab eventKey={3} title="Highlights">
              Highlights
            </Tab>
            <Tab eventKey={4} title="Interactions">
              Interactions
            </Tab>
            <Tab eventKey={5} title="Taxonomy">
              Taxonomy
            </Tab>
            <Tab eventKey={6}title="Names">
              Names
            </Tab>
            <Tab eventKey={7} title="Status">
              Status
            </Tab>
          </Tabs>
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
