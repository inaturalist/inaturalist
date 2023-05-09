import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import News from "./news";
import Requirements from "./requirements";
import EventCountdown from "./event_countdown";
import OverviewMap from "./overview_map";

const BeforeEventTab = props => {
  const { project, config, updateCurrentUser, fetchPosts } = props;
  return (
    <div className="OverviewTab">
      <Grid className="info-grid">
        <Row>
          <Col xs={4}>
            <h2>
              { I18n.t( "status" ) }
            </h2>
            <EventCountdown
              startTimeObject={project.startDate}
            />
          </Col>
          <Col xs={4}>
            <Requirements {...props} includeArrowLink />
          </Col>
          <Col xs={4}>
            <LazyLoad
              debounce={false}
              height={90}
              offset={100}
              onContentVisible={fetchPosts}
            >
              <News {...props} />
            </LazyLoad>
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
  updateCurrentUser: PropTypes.func,
  fetchPosts: PropTypes.func
};

export default BeforeEventTab;
