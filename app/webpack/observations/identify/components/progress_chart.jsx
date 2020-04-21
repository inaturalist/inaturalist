import React from "react";
import PropTypes from "prop-types";

const ProgressChart = ( {
  reviewed,
  unreviewed
} ) => (
  <div className="ProgressChart">
    <div className="title">
      <span
        dangerouslySetInnerHTML={{
          __html: I18n.t( "x_observations_reviewed_html", {
            count: I18n.toNumber( reviewed, { precision: 0 } )
          } )
        }}
      />
    </div>
    <div className="chart">
      <div
        className="value"
        style={{ width: `${( reviewed / ( reviewed + unreviewed ) ) * 100}%` }}
      />
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
