import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import DonateButtonBanner from "./donate_button_banner";
import DonateNeedsSupport from "./donate_needs_support";
import DonateThanks from "./donate_thanks";
import Sites from "./sites";
import StoreContent2021 from "./store_content_2021";

const DonateContent2022 = ( {
  defaultSiteId,
  forDonor,
  forMonthlyDonor,
  isTouchDevice,
  site,
  sites,
  year
} ) => (
  <div className="DonateContent2022 donate-content">
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
          <Sites year={year} site={site} sites={sites} defaultSiteId={defaultSiteId} />
        </Col>
      </Row>
    </Grid>
    <StoreContent2021 isTouchDevice={isTouchDevice} />
    <Grid fluid={isTouchDevice}>
      <Row>
        <Col xs={12}>
          <DonateThanks />
        </Col>
      </Row>
    </Grid>
    <Grid fluid={isTouchDevice}>
      <Row>
        <Col xs={12}>
          {/*
            <h2>
              <a name="monthly" href="#monthly">
                <span>{I18n.t( "monthly_supporters" )}</span>
              </a>
            </h2>
          */}
          <div className="text-center">
            {
              forMonthlyDonor
                ? (
                  <a
                    href={`/monthly-supporters?utm_campaign=${year}-year-in-review&utm_content=button&utm_term=thank-you-for-being-a-monthly-supporter`}
                    className="btn btn-lg btn-primary btn-bordered"
                  >
                    {
                      I18n.t(
                        "views.donate.monthly_supporters.thank_you_for_being_a_monthly_supporter_caps",
                        {
                          defaultValue: I18n.t(
                            "views.donate.monthly_supporters.thank_you_for_being_a_monthly_supporter"
                          )
                        }
                      )
                    }
                  </a>
                )
                : (
                  <a
                    href={`/monthly-supporters?utm_campaign=${year}-year-in-review&utm_content=button&utm_term=become-a-monthly-supporter`}
                    className="btn btn-lg btn-primary btn-bordered"
                  >
                    {
                      I18n.t(
                        "views.donate.monthly_supporters.become_a_monthly_supporter_of_inaturalist_caps",
                        {
                          defaultValue: I18n.t(
                            "views.donate.monthly_supporters.become_a_monthly_supporter_of_inaturalist"
                          )
                        }
                      )
                    }
                  </a>
                )
            }
          </div>
        </Col>
      </Row>
    </Grid>
  </div>
);

DonateContent2022.propTypes = {
  defaultSiteId: PropTypes.number,
  forDonor: PropTypes.bool,
  forMonthlyDonor: PropTypes.bool,
  isTouchDevice: PropTypes.bool,
  site: PropTypes.object,
  sites: PropTypes.array,
  year: PropTypes.number
};

export default DonateContent2022;
