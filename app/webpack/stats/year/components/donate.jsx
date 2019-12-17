import React from "react";
import PropTypes from "prop-types";

const Donate = ( { year } ) => (
  <div className="Donate">
    <h3>
      <a name="donate" href="#donate">
        <span>{I18n.t( "views.stats.year.donate_title" )}</span>
      </a>
    </h3>
    <p
      dangerouslySetInnerHTML={{
        __html: I18n.t( "views.stats.year.donate_desc_html", {
          team_url: "https://www.inaturalist.org/pages/about",
          seek_url: "https://www.inaturalist.org/pages/seek_app"
        } )
      }}
    />
    <div className="support">
      <a
        href={`/monthly-supporters?utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=button&utm_term=monthly`}
        className="btn btn-default btn-primary btn-bordered btn-donate"
      >
        { I18n.t( "give_monthly_caps" ) }
      </a>
      <a
        href={`/donate?utm_content=utm_campaign=${year}-year-in-review&utm_medium=web&utm_content=button&utm_term=now`}
        className="btn btn-default btn-primary btn-bordered btn-donate"
      >
        { I18n.t( "give_now_caps" ) }
      </a>
    </div>
    <div className="store">
      <div className="prompt">
        <p>{I18n.t( "views.stats.year.store_prompt" )}</p>
        <a
          href="https://store.inaturalist.org"
          className="btn btn-default btn-donate btn-primary btn-bordered"
        >
          { I18n.t( "store" ) }
        </a>
      </div>
      <a
        href="https://store.inaturalist.org"
        className="img-link"
      >
        <img
          alt={I18n.t( "store" )}
          src="https://static.inaturalist.org/misc/yir-inat-shirts.png"
          className="img-responsive"
        />
      </a>
    </div>
  </div>
);

Donate.propTypes = {
  year: PropTypes.number
};

export default Donate;
