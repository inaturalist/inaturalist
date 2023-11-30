import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";

/* global OUTLINK_SITES */

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
        <a name="impacts" href="#impacts">
          <span>{ I18n.t( "views.stats.year.broader_impacts" ) }</span>
        </a>
      </h3>
      <p className="text-muted">
        { I18n.t( "views.stats.year.broader_impacts_desc" ) }
      </p>
      <div className="outlinks-container">
        <div className="outlinks">
          { _.map( data, ( count, source ) => (
            <div className="outlink-with-icon" key={`outlink-${source}`}>
              <div className="icon">
                <a
                  href={OUTLINK_SITES[source].url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <img alt={source} src={OUTLINK_SITES[source].icon} />
                </a>
              </div>
              <div className="title-subtitle">
                <div className="title">
                  <a
                    href={OUTLINK_SITES[source].url}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {source}
                  </a>
                </div>
                <div className="subtitle">
                  <a href={
                    `/observations?place_id=any&verifiable=any&user_id=${user.id}`
                    + `&outlink_source=${source}&year=${year}`
                  }
                  >
                    {I18n.t( "x_observations", { count: I18n.toNumber( count, { precision: 0 } ) } )}
                  </a>
                </div>
              </div>
            </div>
          ) ) }
        </div>
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
