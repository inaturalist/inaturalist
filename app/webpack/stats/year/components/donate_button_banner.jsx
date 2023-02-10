import React from "react";
import PropTypes from "prop-types";

const DonateButtonBanner = ( { forDonor, year } ) => {
  let utmTerm = "become-a-donor-today";
  let btnText = I18n.t( "become_a_donor_today_caps" );
  if ( forDonor ) {
    utmTerm = "donate-again-today";
    btnText = I18n.t( "donate_again_today_caps" );
  }

  return (
    <a
      className="bar"
      href={`/donate?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=banner-global-bottom&utm_term=${utmTerm}`}
    >
      <span className="btn btn-default btn-inat btn-donate">
        { btnText }
      </span>
    </a>
  );
};

DonateButtonBanner.propTypes = {
  forDonor: PropTypes.bool,
  year: PropTypes.number
};

export default DonateButtonBanner;
