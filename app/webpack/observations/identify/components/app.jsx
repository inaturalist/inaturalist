import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ObservationsGridContainer from "../containers/observations_grid_container";
import ObservationModalContainer from "../containers/observation_modal_container";
import SearchBarContainer from "../containers/search_bar_container";
import PaginationControlContainer from "../containers/pagination_control_container";

import SideBar from "./side_bar";

const App = () => (
  <div id="Identify">
    <Grid fluid>
      <Row>
        <Col xs={12}>
          <h2>Identify</h2>
        </Col>
      </Row>
      <Row>
        <Col xs={9}>
          <SearchBarContainer />
        </Col>
      </Row>
      <Row className="mainrow">
        <Col xs={9} className="main-col">
          <ObservationsGridContainer />
          <PaginationControlContainer />
        </Col>
        <Col xs={3} className="sidebar-col">
          <SideBar />
        </Col>
      </Row>
      <ObservationModalContainer />
    </Grid>
  </div>
);
export default App;
