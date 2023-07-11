/*
  * Based on https://github.com/bcbcarl/react-c3js/blob/master/src/index.js
  * Light wrapper around C3. Just pass it a config attribute and follow the c3 docs.
  * As of March 2023, it's a light wrapper around billboard.js, a C3 fork
*/
import React from "react";
import PropTypes from "prop-types";
import { findDOMNode } from "react-dom";
import bb from "billboard.js";

class C3Chart extends React.Component {
  static generateChart( mountNode, config = {} ) {
    return bb.generate( Object.assign( { bindto: mountNode }, config ) );
  }

  componentDidMount( ) {
    const { config } = this.props;
    this.updateChart( config );
  }

  componentWillReceiveProps( newProps ) {
    this.updateChart( newProps.config );
  }

  componentWillUnmount() {
    this.destroyChart();
  }

  destroyChart() {
    try {
      this.chart = this.chart.destroy();
    } catch ( err ) {
      throw new Error( "Internal Billboard error", err );
    }
  }

  updateChart( config = {} ) {
    this.chart = C3Chart.generateChart( findDOMNode( this ), config );
  }

  render() {
    const { className, style } = this.props;
    return <div className={className} style={style || {}} />;
  }
}

C3Chart.propTypes = {
  config: PropTypes.object,
  className: PropTypes.string,
  style: PropTypes.object
};

export default C3Chart;
