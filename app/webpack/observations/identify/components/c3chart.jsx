/**
  * Based on https://github.com/bcbcarl/react-c3js/blob/master/src/index.js
  * Light wrapper around C3. Just pass it a config attribute and follow the c3 docs.
**/
import React from "react";
import PropTypes from "prop-types";
import { findDOMNode } from "react-dom";
import c3 from "c3";

class C3Chart extends React.Component {

  componentDidMount( ) {
    this.updateChart( this.props.config );
  }

  componentWillReceiveProps( newProps ) {
    this.updateChart( newProps.config );
  }

  componentWillUnmount() {
    this.destroyChart();
  }

  generateChart( mountNode, config = {} ) {
    return c3.generate( Object.assign( { bindto: mountNode }, config ) );
  }

  destroyChart() {
    try {
      this.chart = this.chart.destroy();
    } catch ( err ) {
      throw new Error( "Internal C3 error", err );
    }
  }

  updateChart( config = {} ) {
    this.chart = this.generateChart( findDOMNode( this ), config );
  }

  render() {
    const className = this.props.className ? ` ${this.props.className}` : "";
    const style = this.props.style ? this.props.style : {};
    return <div className={className} style={style} />;
  }
}

C3Chart.propTypes = {
  config: PropTypes.object,
  className: PropTypes.string,
  style: PropTypes.object
};

export default C3Chart;
