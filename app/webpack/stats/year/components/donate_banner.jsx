import React from "react";
import PropTypes from "prop-types";

const DonateBanner = ( { forDonor, forUser, year } ) => {
  const utmContent = forUser ? "banner-personal" : "banner-global-top";
  const utmTerm = forDonor ? "donate-again" : "become-a-donor";
  return (
    <a
      className="DonateBanner text-center"
      href={`/donate?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=${utmContent}&utm_term=${utmTerm}`}
    >
      <div>
        { forUser
          ? I18n.t( "yir_donate_banner_you_helped_inaturalist_thrive", {
            defaultValue: I18n.t( "yir_donate_banner_inaturalist_thrives" )
          } )
          : (
            <span>
              <strong>
                { I18n.t( "yir_donate_banner_inaturalist_in_year", { year } ) }
              </strong>
              <br />
              { I18n.t( "yir_donate_banner_reaching_millions" ) }
              { " " }
              <br className="hidden-xs hidden-sm" />
              { I18n.t( "yir_donate_banner_all_thanks" ) }
            </span>
          )
        }
      </div>
      <div>
        <span
          className="btn btn-default btn-inat btn-donate"
        >
          { forDonor ? I18n.t( "donate_again_caps" ) : I18n.t( "become_a_donor_caps" ) }
        </span>
      </div>
    </a>
  );
};

DonateBanner.propTypes = {
  forDonor: PropTypes.bool,
  forUser: PropTypes.bool,
  year: PropTypes.number.isRequired
};

export default DonateBanner;
