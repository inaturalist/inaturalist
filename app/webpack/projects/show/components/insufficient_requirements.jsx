import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import News from "./news";
import Requirements from "./requirements";

const InsufficientRequirements = props => (
  <div>
    <Grid className="info-grid">
      <Row>
        <Col xs={6}>
          <Requirements {...props} includeArrowLink />
        </Col>
        <Col xs={6}>
          <News {...props} />
        </Col>
      </Row>
    </Grid>
  </div>
);

InsufficientRequirements.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setSelectedTab: PropTypes.func,
  updateCurrentUser: PropTypes.func
};

export default InsufficientRequirements;
