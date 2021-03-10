import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import News from "./news";
import Requirements from "./requirements";
import EventCountdown from "./event_countdown";
import OverviewMap from "./overview_map";

const BeforeEventTab = props => {
  const { project, config, updateCurrentUser } = props;
  return (
    <div className="OverviewTab">
      <Grid className="info-grid">
        <Row>
          <Col xs={4}>
            <h2>
              { I18n.t( "status" ) }
            </h2>
            <EventCountdown
              {...props}
              startTimeObject={project.startDate}
            />
          </Col>
          <Col xs={4}>
            <Requirements {...props} includeArrowLink />
          </Col>
          <Col xs={4}>
            <News {...props} />
          </Col>
        </Row>
        { !_.isEmpty( project.placeRules ) && (
          <OverviewMap
            project={project}
            config={config}
            updateCurrentUser={updateCurrentUser}
          />
        ) }
      </Grid>
    </div>
  );
};

BeforeEventTab.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func,
  updateCurrentUser: PropTypes.func
};

export default BeforeEventTab;
