import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import {
  Button,
  Tab,
  Tabs
} from "react-bootstrap";
import TaxonCrumbs from "./taxon_crumbs";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import SeasonalityChartContainer from "../containers/seasonality_chart_container";
import HistoryChartContainer from "../containers/history_chart_container";

const App = () => (
  <div id="TaxonDetail">
    <Grid>
      <Row className="preheader">
        <Col xs={12}>
          <TaxonCrumbs />
          <a href="foo"><i className="fa fa-link"></i></a>
          <Button bsSize="xs" className="pull-right">Search</Button>
        </Col>
      </Row>
      <Row className="header">
        <Col xs={12}>
          <h1 className="pull-left">Taxon Name</h1>
          <Button className="pull-right">Choose Place</Button>
        </Col>
      </Row>
      <Row className="hero">
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
              <Tabs defaultActiveKey={101}>
                <Tab eventKey={101} title="Seasonality">
                  <SeasonalityChartContainer />
                </Tab>
                <Tab eventKey={102} title="History">
                  <HistoryChartContainer />
                </Tab>
              </Tabs>
            </Col>
          </Row>
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

export default App;
