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
import FlashMessage from "../../show/components/flash_message";
import WebinarBannerContainer from "../containers/webinar_banner_container";
import ConfirmModalContainer from "../../../shared/containers/confirm_modal_container";
import ProjectFieldsModalContainer from "../containers/project_fields_modal_container";
import TestGroupToggle from "../../../shared/components/test_group_toggle";

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
    <WebinarBannerContainer />
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
          { config?.currentUser?.privilegedWith( "interaction" ) && (
            <PaginationControlContainer />
          ) }
          <FinishedModalContainer />
          {
            config && config.currentUser
            && (
              config.currentUser.roles.indexOf( "curator" ) >= 0
              || config.currentUser.roles.indexOf( "admin" ) >= 0
              || config.currentUser.sites_admined.length > 0
            )
            && (
              <div className="container upstacked">
                <div className="row">
                  <div className="cols-xs-12">
                    <TestGroupToggle
                      group="apiv2"
                      joinPrompt="Test API V2? You can also use the test=apiv2 URL param"
                      joinedStatus="Joined API V2 test"
                      user={config.currentUser}
                    />
                  </div>
                </div>
              </div>
            )
          }
        </div>
        { config?.currentUser?.privilegedWith( "interaction" ) && (
          <SideBar
            blind={config.blind}
            hidden={sideBarHidden}
            setSideBarHidden={setSideBarHidden}
          />
        ) }
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
