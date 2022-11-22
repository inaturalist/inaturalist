import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import QueriesContainer from "../containers/queries_container";
import TabsContainer from "../containers/tabs_container";
import TaxonChildrenModalContainer from "../containers/taxon_children_modal_container";

const App = ( ) => (
  <div id="Compare">
    <Grid fluid>
      <Row>
        <Col xs={12}>
          <QueriesContainer />
        </Col>
      </Row>
      <Row>
        <Col xs={12}>
          <TabsContainer />
        </Col>
      </Row>
      <Row>
        <Col xs={12}>
          <div className="alert alert-warning text-center">
            This tool is experimental. It might be broken, and may be removed at any time.
          </div>
        </Col>
      </Row>
    </Grid>
    <TaxonChildrenModalContainer />
  </div>
);

export default App;
