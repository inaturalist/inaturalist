import React from "react";
import PropTypes from "prop-types";
// I18n.t( "date.formats.month_year" )

const Donor = ( {
  user,
  year
} ) => (
  <div className="Donor">
    <i className="icon-logomark" />
    <span
      dangerouslySetInnerHTML={{
        __html: I18n.t( "monthly_supporter_since_date_html", {
          date: I18n.localize( "date.formats.month_year", new Date( user.display_donor_since ) ),
          url: `/monthly-supporters?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=inline-link&utm_term=${user.login}`
        } )
      }}
    />
  </div>
);

Donor.propTypes = {
  user: PropTypes.object.isRequired,
  year: PropTypes.number
};

export default Donor;
