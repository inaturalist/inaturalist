import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import Uploader from "../containers/uploader";
import Table from "../containers/table";

const App = ( ) => (
  <Grid fluid>
    <Row>
      <Col xs={12}>
        <Uploader />
      </Col>
    </Row>
  </Grid>
);

export default App;
