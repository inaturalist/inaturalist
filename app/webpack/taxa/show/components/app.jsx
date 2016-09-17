import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import {
  Button,
  Tab,
  Tabs
} from "react-bootstrap";
import SplitTaxon from "../../../observations/identify/components/split_taxon";
import TaxonMap from "../../../observations/identify/components/taxon_map";
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
          <TaxonCrumbs
            taxon={taxon}
            ancestors={taxon.ancestors}
            url={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}
          />
          <a href={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}>
            <i className="glyphicon glyphicon-link"></i>
          </a>
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
          <Grid>
            <Row>
              <Col xs={12}>
                <ul className="nav nav-tabs" role="tablist">
                  <li role="presentation" className="active">
                    <a href="#map-tab" role="tab" data-toggle="tab">{ I18n.t( "map" ) }</a>
                  </li>
                  <li role="presentation">
                    <a href="#articles-tab" role="tab" data-toggle="tab">{ I18n.t( "articles" ) }</a>
                  </li>
                  <li role="presentation">
                    <a href="#highlights-tab" role="tab" data-toggle="tab">{ I18n.t( "highlights" ) }</a>
                  </li>
                  <li role="presentation">
                    <a href="#interactions-tab" role="tab" data-toggle="tab">{ I18n.t( "interactions" ) }</a>
                  </li>
                  <li role="presentation">
                    <a href="#taxonomy-tab" role="tab" data-toggle="tab">{ I18n.t( "taxonomy" ) }</a>
                  </li>
                  <li role="presentation">
                    <a href="#names-tab" role="tab" data-toggle="tab">{ I18n.t( "names" ) }</a>
                  </li>
                  <li role="presentation">
                    <a href="#status-tab" role="tab" data-toggle="tab">{ I18n.t( "status" ) }</a>
                  </li>
                </ul>
              </Col>
            </Row>
          </Grid>

          <div className="tab-content">
            <div role="tabpanel" className="tab-pane active" id="map-tab">
              <TaxonMap
                className="row"
                scrollwheel={false}
                showAllLayer={false}
                minZoom={2}
                taxonLayers={[{
                  taxon,
                  observations: true
                }] }
              />
            </div>
            <div role="tabpanel" className="tab-pane" id="articles-tab">
              <Grid>
                <Row>
                  <Col xs={12}>
                    articles go here
                  </Col>
                </Row>
              </Grid>
            </div>
            <div role="tabpanel" className="tab-pane" id="highlights-tab">
              <Grid>
                <Row>
                  <Col xs={12}>
                    highlights go here
                  </Col>
                </Row>
              </Grid>
            </div>
            <div role="tabpanel" className="tab-pane" id="interactions-tab">
              <Grid>
                <Row>
                  <Col xs={12}>
                    interactions go here
                  </Col>
                </Row>
              </Grid>
            </div>
            <div role="tabpanel" className="tab-pane" id="taxonomy-tab">
              <Grid>
                <Row>
                  <Col xs={12}>
                    taxonomy goes here
                  </Col>
                </Row>
              </Grid>
            </div>
            <div role="tabpanel" className="tab-pane" id="names-tab">
              <Grid>
                <Row>
                  <Col xs={12}>
                    names go here
                  </Col>
                </Row>
              </Grid>
            </div>
            <div role="tabpanel" className="tab-pane" id="status-tab">
              <Grid>
                <Row>
                  <Col xs={12}>
                    status goes here
                  </Col>
                </Row>
              </Grid>
            </div>
          </div>
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
