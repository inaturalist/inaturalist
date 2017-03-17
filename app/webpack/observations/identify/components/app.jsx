import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ObservationsGridContainer from "../containers/observations_grid_container";
import ObservationModalContainer from "../containers/observation_modal_container";
import SearchBarContainer from "../containers/search_bar_container";
import PaginationControlContainer from "../containers/pagination_control_container";
import FinishedModalContainer from "../containers/finished_modal_container";
import SideBar from "./side_bar";
import AlertModalContainer from "../containers/alert_modal_container";

const App = ( { blind } ) => (
  <div id="Identify" className={ blind ? "blind" : "" }>
    <Grid fluid>
      { blind ? (
        <Row>
          <Col xs={12}>
            <div className="alert alert-warning">
              <p><strong>You're Identifying Blind!</strong></p>
              <p>Thanks for volunteering to improve iNaturalist's data quality.
              You're using a modified version of our Identify where you are
              "blind" to biasing details like the opinions of others. Obviously
              we can't stop you from using the non-blind version, but we'd
              appreciate it if you stayed on this page while participating in
              this process and not "peek" at other pages that would provide you
              with social context.</p>
            </div>
          </Col>
        </Row>
      ) : null }
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

App.propTypes = {
  blind: React.PropTypes.bool
};

export default App;
