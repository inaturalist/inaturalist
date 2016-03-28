import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";
import StatsControlItem from "./stats_control_item";

const StatsControl = ( {
  stats
} ) => (
  <Row>
    <Col xs={2} className="statcol">
      <StatsControlItem title={ I18n.t( "needs_id" ) } value={stats.needsId} />
    </Col>
    <Col xs={2} className="statcol">
      <StatsControlItem
        title={ I18n.t( "research_grade" ) }
        value={stats.research}
      />
    </Col>
    <Col xs={2} className="statcol">
      <StatsControlItem title={ I18n.t( "casual" ) } value={stats.casual} />
    </Col>
  </Row>
);

StatsControl.propTypes = {
  stats: PropTypes.object
};

export default StatsControl;
