import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ObservationsGridContainer from "../containers/observations_grid_container";
import ObservationModalContainer from "../containers/observation_modal_container";
import SearchBarContainer from "../containers/search_bar_container";
import PaginationControlContainer from "../containers/pagination_control_container";
import FinishedModalContainer from "../containers/finished_modal_container";
import SideBar from "./side_bar";
import AlertModalContainer from "../containers/alert_modal_container";

const App = () => (
  <div id="Identify">
    <Grid fluid>
      <Row>
        <Col xs={12}>
          <h2>{ I18n.t( "identify_title" ) }</h2>
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
          <FinishedModalContainer />
        </Col>
        <Col xs={3} className="sidebar-col">
          <SideBar />
        </Col>
      </Row>
      <ObservationModalContainer />
      <AlertModalContainer />
    </Grid>
  </div>
);
export default App;
