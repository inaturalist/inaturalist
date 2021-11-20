import React from "react";
import PropTypes from "prop-types";

const DonateBanner = ( { user, year } ) => {
  const bannerDonateButton = (
    <a
      href={`/monthly-supporters?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=button&utm_term=become_a_donor`}
      className="btn btn-default btn-inat btn-donate"
    >
      { I18n.t( "become_a_donor_caps" ) }
    </a>
  );
  const message = user
    ? (
      <div>
        { I18n.t( "yir_donate_banner_inaturalist_thrives" ) }
      </div>
    )
    : (
      <div>
        <strong>
          { I18n.t( "yir_donate_banner_inaturalist_in_year", { year } ) }
        </strong>
        <br />
        { I18n.t( "yir_donate_banner_reaching_millions" ) }
        <br />
        { I18n.t( "yir_donate_banner_all_thanks" ) }
      </div>
    );
  return (
    <div className="DonateBanner text-center">
      { message }
      <div>
        { bannerDonateButton }
      </div>
    </div>
  );
};

DonateBanner.propTypes = {
  user: PropTypes.object,
  year: PropTypes.number.isRequired
};

export default DonateBanner;
