import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import c3 from "c3";

class Histogram extends React.Component {
  componentDidMount( ) {
    this.renderHistogram( );
  }

  renderHistogram( ) {
    const config = _.defaultsDeep( { }, {
      data: {
        columns: this.props.columns
      },
      zoom: {
        enabled: true,
        rescale: true
      }
    }, this.props.config );
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    this.historyChart = c3.generate( Object.assign( { bindto: mountNode }, config ) );
  }

  render( ) {
    return (
      <div className="Histogram">
        <div className="chart"></div>
      </div>
    );
  }
}

Histogram.propTypes = {
  columns: PropTypes.array,
  config: PropTypes.object
};

Histogram.defaultProps = {
  config: {}
};

export default Histogram;
