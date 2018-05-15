import React, { Component, PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import UmbrellaLeaderboardContainer from "../containers/umbrella_leaderboard_container";
import UmbrellaMapContainer from "../containers/umbrella_map_container";
import RecentObservationsContainer from "../containers/recent_observations_container";
import PhotoModalContainer from "../../../taxa/show/containers/photo_modal_container";
import UmbrellaNews from "./umbrella_news";
import FlagAnItemContainer from "../../../shared/containers/flag_an_item_container";

class UmbrellaOverviewTab extends Component {
  render( ) {
    const { project } = this.props;
    if ( !project.umbrella_stats_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    return (
      <div className="UmbrellaOverviewTab">
        <Grid>
          <Row>
            <Col xs={ 12 }>
              <UmbrellaLeaderboardContainer />
            </Col>
          </Row>
        </Grid>
        <UmbrellaMapContainer />
        <RecentObservationsContainer />
        <PhotoModalContainer />
        <UmbrellaNews { ...this.props } />
        <Grid>
          <Row>
            <Col xs={ 12 }>
              <FlagAnItemContainer
                item={ project }
                manageFlagsPath={ `/flags?project_id=${project.id}` }
              />
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
}


UmbrellaOverviewTab.propTypes = {
  setConfig: PropTypes.func,
  project: PropTypes.object,
  config: PropTypes.object
};

export default UmbrellaOverviewTab;
