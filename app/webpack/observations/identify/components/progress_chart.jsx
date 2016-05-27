import React, { PropTypes } from "react";

const ProgressChart = ( {
  reviewed,
  unreviewed
} ) => (
  <div className="ProgressChart">
    <div className="title">
      <span className="count">
        { I18n.toNumber( reviewed, { precision: 0 } ) }
      </span> Observations Reviewed
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
