import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";

/* global OUTLINK_SITE_ICONS */

const BroaderImpacts = ( {
  data,
  user,
  year
} ) => {
  if ( _.isEmpty( data ) ) {
    return null;
  }
  return (
    <div className="BroaderImpacts">
      <h3>
        <a name="streaks" href="#streaks">
          <span>{ I18n.t( "views.stats.year.broader_impacts" ) }</span>
        </a>
      </h3>
      <p className="text-muted">
        { I18n.t( "views.stats.year.broader_impacts_desc" ) }
      </p>
      <div className="outlinks">
        { _.map( data, ( count, source ) => (
          <div className="outlink-with-icon">
            <div className="icon">
              <img alt={source} src={OUTLINK_SITE_ICONS[source]} />
            </div>
            <div className="title-subtitle">
              <div className="title">{source}</div>
              <div className="subtitle">
                <a href={`/observations?verifiable=any&user_id=${user.id}&outlink_source=${source}&year=${year}`}>
                  {I18n.t( "x_observations", { count: I18n.toNumber( count, { precision: 0 } ) } )}
                </a>
              </div>
            </div>
          </div>
        ) ) }
      </div>
    </div>
  );
};

BroaderImpacts.propTypes = {
  data: PropTypes.array.isRequired,
  user: PropTypes.object.isRequired,
  year: PropTypes.number.isRequired
};

export default BroaderImpacts;
