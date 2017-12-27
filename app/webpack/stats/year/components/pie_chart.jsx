import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";
import d3tip from "d3-tip";
import legend from "d3-svg-legend";

class PieChart extends React.Component {
  componentDidMount( ) {
    this.renderPieChart( );
  }

  renderPieChart( ) {
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const svg = d3.select( mountNode ).append( "svg" );
    const margin = this.props.margin;
    const svgWidth = $( "svg", mountNode ).width( );
    const svgHeight = $( "svg", mountNode ).height( );
    // Set viewBox and preserveAspectRatio so the SVG resizes with the window... kinda (not the height)
    // https://stackoverflow.com/questions/9400615/whats-the-best-way-to-make-a-d3-js-visualisation-layout-responsive#9539361
    svg
      .attr( "width", svgWidth )
      .attr( "height", svgHeight )
      .attr( "viewBox", `0 0 ${svgWidth} ${svgHeight}` )
      .attr( "preserveAspectRatio", "xMidYMid meet" );
    const width = svgWidth - margin.left - margin.right;
    const height = svgHeight - margin.top - margin.bottom;
    const radius = Math.min( width, height ) / 2;
    const g = svg.append( "g" ).attr( "transform", `translate(${width / 2},${height / 2})` );
    const color = d3.scaleOrdinal( d3.schemeCategory20 );
    const colorForDatum = datum => ( datum.color || color( datum.label ) );

    const data = this.props.data;

    // Setup tips
    const angleInBottomHalf = angle => ( angle > ( Math.PI / 2 ) && angle < ( 1.5 * Math.PI ) );
    const tip = d3tip()
      .attr( "class", "d3-tip" )
      .offset( d => {
        const midAngle = d.startAngle + ( d.endAngle - d.startAngle ) / 2;
        if ( angleInBottomHalf( midAngle ) ) {
          return [10, 0];
        }
        return [-10, 0];
      } )
      .direction( d => {
        const midAngle = d.startAngle + ( d.endAngle - d.startAngle ) / 2;
        if ( angleInBottomHalf( midAngle ) ) {
          return "s";
        }
        return "n";
      } )
      .html( d => {
        if ( this.props.labelForDatum ) {
          return this.props.labelForDatum( d );
        }
        const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
        const percent = _.round( degrees / 360 * 100, 2 );
        return `<strong>${d.data.label}</strong>: ${I18n.toNumber( d.value, { precision: 0 } )} (${percent}%)`;
      } );
    svg.call( tip );

    let innerRadius = 0;
    if ( this.props.innerRadius ) {
      innerRadius = this.props.innerRadius;
    } else if ( this.props.donutWidth ) {
      innerRadius = radius - 10 - this.props.donutWidth;
    }

    // Make the pie chart
    const pie = d3.pie( )
      .sort( null )
      .value( d => d.value );
    const path = d3.arc( )
      .outerRadius( radius - 10 )
      .innerRadius( innerRadius );
    const arcGroup = g.selectAll( ".arc" )
      .data( pie( data ) )
      .enter( ).append( "g" )
        .attr( "class", "arc" );
    const arc = arcGroup.append( "path" )
      .attr( "d", path )
      .attr( "class", d => d.data.label )
      .attr( "fill", d => colorForDatum( d.data ) )
      .on( "mouseover", tip.show )
      .on( "mouseout", tip.hide );
    if ( this.props.onClick ) {
      arc.on( "click", this.props.onClick ).style( "cursor", "pointer" );
    }

    // Make the legend
    const legendColumnWidth = this.props.legendColumnWidth || svgWidth;
    const legendWidth = this.props.legendColumns * legendColumnWidth;
    const legendLeft = (
      ( svgWidth / 2 ) - ( legendWidth / 2 )
    );
    const legendGroup = svg.append( "g" )
      .attr( "transform", `translate(${legendLeft},${height + 10})` );
    let legendPosition = margin.left;
    const chunkSize = _.ceil( data.length / this.props.legendColumns );
    _.forEach( _.chunk( data, chunkSize ), ( chunk, i ) => {
      const className = `legendOrdinal-${i}`;
      legendGroup.append( "g" )
        .attr( "class", className )
        .attr( "transform", `translate(${legendPosition},${0})` );
      const legendScale = d3.scaleOrdinal( )
        .domain( chunk.map( d => d.label ) )
        .range( chunk.map( d => colorForDatum( d ) ) );
      const legendOrdinal = legend.legendColor()
        .labels( chunk.map( d => d.label ) )
        .classPrefix( "legend" )
        .shape( "path", d3.symbol( ).type( d3.symbolCircle ).size( 100 )( ) )
        .shapePadding( 5 )
        .orient( this.props.legendOrient )
        .shapePadding( this.props.legendShapePadding )
        .scale( legendScale );
      legendGroup.select( `.${className}` )
        .call( legendOrdinal );
      legendPosition += legendColumnWidth;
    } );
  }

  render( ) {
    return (
      <div className="PieChart">
        <div className="chart"></div>
      </div>
    );
  }
}

PieChart.propTypes = {
  data: PropTypes.array,
  legendColumns: PropTypes.number,
  legendColumnWidth: PropTypes.number,
  legendOrient: PropTypes.string,
  legendShapePadding: PropTypes.number,
  margin: PropTypes.object,
  labelForDatum: PropTypes.func,
  innerRadius: PropTypes.number,
  donutWidth: PropTypes.number,
  onClick: PropTypes.func
};

PieChart.defaultProps = {
  data: [],
  legendColumns: 1,
  legendOrient: "vertical",
  legendShapePadding: 2,
  margin: { top: 0, right: 0, bottom: 0, left: 0 }
};

export default PieChart;
