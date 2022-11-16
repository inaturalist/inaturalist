import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import Donors from "./donors";
import MonthlySupporters from "./monthly_supporters";

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
          { data.budget && data.budget.monthly_supporters && (
            <MonthlySupporters year={year} data={data.budget.monthly_supporters} />
          ) }
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

const StoreContent = ( { isTouchDevice } ) => (
  <Grid fluid={isTouchDevice} className="store">
    <Row>
      <Col xs={12}>
        <a
          href="https://store.inaturalist.org"
          className="img-link"
        >
          <img
            alt={I18n.t( "store" )}
            src="https://static.inaturalist.org/misc/yir-inat-shirts-2020.png"
            className="img-responsive"
          />
        </a>
        <div className="prompt">
          <p>{I18n.t( "views.stats.year.store_prompt" )}</p>
          <a
            href="https://store.inaturalist.org"
            className="btn btn-default btn-donate btn-bordered"
          >
            <i className="fa fa-shopping-cart" />
            { I18n.t( "store" ) }
          </a>
        </div>
      </Col>
    </Row>
  </Grid>
);

StoreContent.propTypes = {
  isTouchDevice: PropTypes.bool
};

const DonateContent2021 = ( { forDonor, isTouchDevice, year } ) => {
  let utmTerm = "become-a-donor-today";
  let btnText = I18n.t( "become_a_donor_today_caps" );
  if ( forDonor ) {
    utmTerm = "donate-again-today";
    btnText = I18n.t( "donate_again_today_caps" );
  }
  return (
    <div className="DonateContent2021">
      <Grid fluid={isTouchDevice}>
        <Row>
          <Col xs={12}>
            <h3>
              <a name="donate" href="#donate">
                <span>{I18n.t( "yir_donate_inaturalist_needs_your_support" )}</span>
              </a>
            </h3>
            <div className="flex-row">
              <div className="donate-image" />
              <div>
                <ul>
                  <li><p>{ I18n.t( "yir_millions_of_people_used_inaturalist" ) }</p></li>
                  <li><p>{ I18n.t( "yir_generating_and_sharing" ) }</p></li>
                  <li><p>{ I18n.t( "yir_your_gift_sustains" ) }</p></li>
                </ul>
              </div>
            </div>
          </Col>
        </Row>
      </Grid>
      <a
        className="bar"
        href={`/donate?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=banner-global-bottom&utm_term=${utmTerm}`}
      >
        <span
          className="btn btn-default btn-inat btn-donate"
        >
          { btnText }
        </span>
      </a>
      <Grid fluid={isTouchDevice}>
        <Row>
          <Col xs={12}>
            <h3>
              <a name="thanks" href="#thanks">
                <span>{I18n.t( "views.stats.year.donate_title" )}</span>
              </a>
            </h3>
            <p>{ I18n.t( "yir_thank_your_for_being_generous" ) }</p>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

DonateContent2021.propTypes = {
  forDonor: PropTypes.bool,
  isTouchDevice: PropTypes.bool,
  year: PropTypes.number
};

const StoreContent2021 = ( { isTouchDevice } ) => (
  <Grid fluid={isTouchDevice} className="StoreContent2021">
    <Row>
      <Col xs={12}>
        <h3>
          <a name="store" href="#store">
            <span>{I18n.t( "check_out_the_inat_store" )}</span>
          </a>
        </h3>
        <a
          href="https://store.inaturalist.org"
          className="img-link"
        >
          <img
            alt={I18n.t( "store" )}
            src="https://static.inaturalist.org/misc/2021-yir/2021-yir-store.png"
            className="img-responsive"
          />
        </a>
      </Col>
    </Row>
  </Grid>
);

StoreContent2021.propTypes = {
  isTouchDevice: PropTypes.bool
};

const Donate = ( { forDonor, year, data } ) => {
  let storeContent;
  let donateContent;
  // https://gist.github.com/59naga/ed6714519284d36792ba
  const isTouchDevice = navigator.userAgent.match(
    /(Android|webOS|iPhone|iPad|iPod|BlackBerry|Windows Phone)/i
  ) !== null;
  if ( year >= 2021 ) {
    storeContent = <StoreContent2021 isTouchDevice={isTouchDevice} />;
    donateContent = (
      <DonateContent2021 forDonor={forDonor} year={year} isTouchDevice={isTouchDevice} />
    );
  } else {
    storeContent = <StoreContent isTouchDevice={isTouchDevice} />;
    donateContent = <DonateContent year={year} data={data} isTouchDevice={isTouchDevice} />;
  }

  return (
    <div className="Donate">
      { storeContent }
      { donateContent }
    </div>
  );
};

Donate.propTypes = {
  forDonor: PropTypes.bool,
  year: PropTypes.number,
  data: PropTypes.object
};

export default Donate;
