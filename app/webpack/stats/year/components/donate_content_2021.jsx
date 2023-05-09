import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import DonateButtonBanner from "./donate_button_banner";
import DonateNeedsSupport from "./donate_needs_support";
import DonateThanks from "./donate_thanks";

const DonateContent2021 = ( { forDonor, isTouchDevice, year } ) => (
  <div className="DonateContent2021 donate-content">
    <Grid fluid={isTouchDevice}>
      <Row>
        <Col xs={12}>
          <DonateNeedsSupport />
        </Col>
      </Row>
    </Grid>
    <DonateButtonBanner forDonor={forDonor} year={year} />
    <Grid fluid={isTouchDevice}>
      <Row>
        <Col xs={12}>
          <DonateThanks />
        </Col>
      </Row>
    </Grid>
  </div>
);

DonateContent2021.propTypes = {
  forDonor: PropTypes.bool,
  isTouchDevice: PropTypes.bool,
  year: PropTypes.number
};

export default DonateContent2021;
