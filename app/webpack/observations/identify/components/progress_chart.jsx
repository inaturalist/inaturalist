import React from "react";
import PropTypes from "prop-types";

class ProgressChart extends React.Component {
  componentDidMount( ) {
    this.props.fetchObservationsStats( );
  }

  render( ) {
    const { reviewed, unreviewed } = this.props;
    return (
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
  }
}

ProgressChart.propTypes = {
  reviewed: PropTypes.number,
  unreviewed: PropTypes.number,
  fetchObservationsStats: PropTypes.func
};

export default ProgressChart;
