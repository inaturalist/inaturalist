import React from "react";
import { Row, Col } from "react-bootstrap";
import StatsControlItem from "./stats_control_item";

const StatsControl = () => (
  <Row>
    <Col xs={2} className="statcol">
      <StatsControlItem title={ I18n.t( "needs_id" ) } value={1234} />
    </Col>
    <Col xs={2} className="statcol">
      <StatsControlItem title={ I18n.t( "research_grade" ) } value={1234} />
    </Col>
    <Col xs={2} className="statcol">
      <StatsControlItem title={ I18n.t( "casual" ) } value={1234} />
    </Col>
  </Row>
);

export default StatsControl;
