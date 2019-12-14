import React from "react";
import PropTypes from "prop-types";

const Donate = ( { year } ) => (
  <div className="Donate">
    <h3>
      <a name="donate" href="#donate">
        <span>{I18n.t( "views.stats.year.donate_title" )}</span>
      </a>
    </h3>
    <p>{I18n.t( "views.stats.year.donate_desc" )}</p>
    <div className="support">
      <a
        href={`/monthly-supporters?utm_content=year-in-review-${year}`}
        className="btn btn-default btn-primary btn-bordered btn-donate"
      >
        { I18n.t( "give_monthly" ) }
      </a>
      <a
        href={`/monthly-supporters?utm_content=year-in-review-${year}`}
        className="btn btn-default btn-primary btn-bordered btn-donate"
      >
        { I18n.t( "give_now" ) }
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
        className="btn btn-default btn-donate img-link"
      >
        <img
          alt={I18n.t( "store" )}
          src="https://static.inaturalist.org/wiki_page_attachments/1462-original.png"
          className="img-responsive"
        />
      </a>
    </div>
  </div>
);

Donate.propTypes = {
  year: PropTypes.number
}

export default Donate;
