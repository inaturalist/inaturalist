import React from "react";

const StatsControlItem = ( {
  title,
  value
} ) => (
  <div className="stat">
    <div className="stat-value">{value === undefined ? "--" : value}</div>
    <div className="stat-title">
      { title }
    </div>
  </div>
);

StatsControlItem.propTypes = {
  title: React.PropTypes.string.isRequired,
  value: React.PropTypes.number
};

export default StatsControlItem;
