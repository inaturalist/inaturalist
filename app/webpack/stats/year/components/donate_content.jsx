import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import Donors from "./donors";

const DonateContent = ( { year, data, isTouchDevice } ) => (
  <Grid fluid={isTouchDevice}>
    <Row>
      <Col xs={12}>
        <h3>
          <a name="donate" href="#donate">
            <span>{I18n.t( "views.stats.year.donate_title" )}</span>
          </a>
        </h3>
        <p
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.stats.year.donate_desc_html", {
              team_url: "https://www.inaturalist.org/pages/about",
              seek_url: "https://www.inaturalist.org/pages/seek_app",
              year
            } )
          }}
        />
        <div className="support-row flex-row">
          <div className="support">
            <a
              href={`/monthly-supporters?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=button&utm_term=monthly`}
              className="btn btn-default btn-primary btn-bordered btn-donate"
            >
              <i className="fa fa-calendar" />
              { I18n.t( "give_monthly_caps" ) }
            </a>
            <a
              href={`/donate?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=button&utm_term=now`}
              className="btn btn-default btn-primary btn-bordered btn-donate"
            >
              <i className="fa fa-heart" />
              { I18n.t( "give_now_caps" ) }
            </a>
          </div>
          { data.budget && data.budget.donors && <Donors year={year} data={data.budget.donors} /> }
        </div>
      </Col>
    </Row>
  </Grid>
);

DonateContent.propTypes = {
  year: PropTypes.number,
  data: PropTypes.object,
  isTouchDevice: PropTypes.bool
};

export default DonateContent;
