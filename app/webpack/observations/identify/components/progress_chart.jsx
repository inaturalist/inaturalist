import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";

const ProgressChart = ( {
  reviewed,
  unreviewed
} ) => (
  <div className="ProgressChart">
    <div className="title">
      <span
        dangerouslySetInnerHTML={ { __html:
          _.capitalize( I18n.t( "x_observations_reviewed_html",
            { count: I18n.toNumber( reviewed, { precision: 0 } ) }
          ) )
        } }
      ></span>
    </div>
    <div className="chart">
      <div
        className="value"
        style={ { width: `${( reviewed / ( reviewed + unreviewed ) ) * 100}%` } }
      >
      </div>
    </div>
    <div className="footer">
      0
      <span className="pull-right">
        { I18n.toNumber( reviewed + unreviewed, { precision: 0 } ) }
      </span>
    </div>
  </div>
);

ProgressChart.propTypes = {
  reviewed: PropTypes.number,
  unreviewed: PropTypes.number
};

export default ProgressChart;
