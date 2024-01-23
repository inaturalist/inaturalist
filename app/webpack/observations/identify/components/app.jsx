import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import ObservationsGridContainer from "../containers/observations_grid_container";
import ObservationModalContainer from "../containers/observation_modal_container";
import SearchBarContainer from "../containers/search_bar_container";
import PaginationControlContainer from "../containers/pagination_control_container";
import FinishedModalContainer from "../containers/finished_modal_container";
import SideBar from "./side_bar";
import AlertModalContainer from "../../../shared/containers/alert_modal_container";
import FlaggingModalContainer from "../containers/flagging_modal_container";
import DisagreementAlertContainer from "../containers/disagreement_alert_container";
import ModeratorActionModalContainer from "../containers/moderator_action_modal_container";
import TestGroupToggle from "../../../shared/components/test_group_toggle";
import FlashMessage from "../../show/components/flash_message";
import ConfirmModalContainer from "../../show/containers/confirm_modal_container";
import ProjectFieldsModalContainer from "../containers/project_fields_modal_container";

const App = ( { sideBarHidden, setSideBarHidden, config } ) => (
  <div id="Identify" className={config.blind ? "blind" : ""}>
    { config && config.testingApiV2 && (
      <FlashMessage
        key="testing_apiv2"
        title="Testing API V2"
        message="This page is using V2 of the API. Please report any differences from using the page w/ API v1 at https://forum.inaturalist.org/t/v2-feedback/21215"
        type="warning"
        html
      />
    ) }
    <Grid fluid>
      <Row>
        <Col xs={12}>
          <h2>{ config.blind ? "Identification Quality Experiment" : I18n.t( "identify_title" ) }</h2>
        </Col>
      </Row>
      <Row>
        <Col xs={12}>
          <SearchBarContainer />
        </Col>
      </Row>
      <Row className={`mainrow ${sideBarHidden && "side-bar-hidden"}`}>
        <div className="main-col">
          <ObservationsGridContainer />
          <PaginationControlContainer />
          <FinishedModalContainer />
        </div>
        <SideBar
          blind={config.blind}
          hidden={sideBarHidden}
          setSideBarHidden={setSideBarHidden}
        />
      </Row>
      <ObservationModalContainer />
      <AlertModalContainer />
      <FlaggingModalContainer />
      <DisagreementAlertContainer />
      <ModeratorActionModalContainer />
      <ConfirmModalContainer />
      <ProjectFieldsModalContainer />
    </Grid>
  </div>
);

App.propTypes = {
  config: PropTypes.object,
  sideBarHidden: PropTypes.bool,
  setSideBarHidden: PropTypes.func
};

export default App;
