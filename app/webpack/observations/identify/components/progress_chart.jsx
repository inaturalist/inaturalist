import React, { PropTypes } from "react";
import C3Chart from "./c3chart";


const ProgressChart = ( {
  reviewed,
  unreviewed
} ) => (
  <div className="ProgressChart">
    <C3Chart
      config={{
        size: {
          height: 230
        },
        data: {
          columns: [
            ["reviewed", reviewed],
            ["unreviewed", unreviewed]
          ],
          type: "donut"
        },
        legend: { show: false },
        donut: {
          width: 35,
          expand: false,
          label: { show: false }
        },
        tooltip: { show: false }
      }}
    />
    <div className="title">
      <div className="counts">
        { reviewed }
        /
        <wbr />
        { reviewed + unreviewed }
      </div>
      { I18n.t( "reviewed" ) }
    </div>
  </div>
);

ProgressChart.propTypes = {
  reviewed: PropTypes.number,
  unreviewed: PropTypes.number
};

export default ProgressChart;
