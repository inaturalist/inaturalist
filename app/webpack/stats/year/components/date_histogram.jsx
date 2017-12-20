import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";
import d3tip from "d3-tip";
import legend from "d3-svg-legend";

class DateHistogram extends React.Component {
  componentDidMount( ) {
    this.renderHistogram( );
  }

  renderHistogram( ) {
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const svg = d3.select( mountNode ).append( "svg" );
    const margin = { top: 20, right: 20, bottom: 30, left: 50 };
    const width = $( "svg", mountNode ).width( ) - margin.left - margin.right;
    const height = $( "svg", mountNode ).height( ) - margin.top - margin.bottom;
    const g = svg.append( "g" ).attr( "transform", `translate(${margin.left}, ${margin.top})` );

    const parseTime = d3.timeParse( "%Y-%m-%d" );
    const series = {};
    _.forEach( this.props.series, ( s, seriesName ) => {
      series[seriesName] = _.map( s.data, d => ( {
        date: parseTime( d.date ),
        value: d.value,
        seriesName
      } ) );
    } );
    const x = d3.scaleTime( ).rangeRound( [0, width] );
    const y = d3.scaleLinear( ).rangeRound( [height, 0] );
    const line = d3.line( )
        .x( d => x( d.date ) )
        .y( d => y( d.value ) );

    const combinedData = _.flatten( _.values( series ) );
    x.domain( d3.extent( combinedData, d => d.date ) );
    y.domain( d3.extent( combinedData, d => d.value ) );

    g.append( "g" )
        .attr( "transform", `translate(0,${height})` )
        .call( d3.axisBottom( x ) )
        .select( ".domain" )
              .remove();

    g.append( "g" )
        .call( d3.axisLeft( y ) );

    const dateFormatter = d3.timeFormat( "%d %b" );
    const tip = d3tip()
      .attr( "class", "d3-tip" )
      .offset( [-10, 0] ).
      html( d => {
        if ( this.props.series[d.seriesName] && this.props.series[d.seriesName].label ) {
          return this.props.series[d.seriesName].label( d );
        }
        return `<strong>${dateFormatter( d.date )}</strong>: ${d.value}`;
      } );
    svg.call( tip );

    const color = d3.scaleOrdinal( d3.schemeCategory10 );
    const colorForSeries = seriesName => {
      if ( this.props.series[seriesName] && this.props.series[seriesName].color ) {
        return this.props.series[seriesName].color;
      }
      return color( seriesName );
    };
    _.forEach( series, ( seriesData, seriesName ) => {
      const seriesGroup = g.append( "g" );
      seriesGroup.classed( _.snakeCase( seriesName ), true );
      if ( this.props.series[seriesName].style === "bar" ) {
        seriesGroup.selectAll( "rect" ).data( seriesData )
          .enter( ).append( "rect" )
            .attr( "width", ( d, i ) => {
              let nextX = width;
              if ( seriesData[i + 1] ) {
                nextX = x( seriesData[i + 1].date );
              }
              return nextX - x( d.date );
            } )
            .attr( "height", d => height - y( d.value ) )
            .attr( "fill", colorForSeries( seriesName ) )
            .attr( "transform", d => `translate( ${x( d.date )}, ${y( d.value )} )` )
            .on( "mouseover", tip.show )
            .on( "mouseout", tip.hide );
      } else {
        seriesGroup.append( "path" ).datum( seriesData )
            .attr( "fill", "none" )
            .attr( "stroke", colorForSeries( seriesName ) )
            .attr( "stroke-linejoin", "round" )
            .attr( "stroke-linecap", "round" )
            .attr( "stroke-width", 1.5 )
            .attr( "d", line );
        seriesGroup.selectAll( "circle" ).data( seriesData )
          .enter().append( "circle" )
            .attr( "cx", d => x( d.date ) )
            .attr( "cy", d => y( d.value ) )
            .attr( "r", 2 )
            .attr( "fill", "white" )
            .style( "stroke", ( ) => colorForSeries( seriesName ) )
            .on( "mouseover", tip.show )
            .on( "mouseout", tip.hide );
      }
    } );

    svg.append( "g" )
      .attr( "class", "legendOrdinal" )
      .attr( "transform", `translate(${width - 20},20)` );
    const legendScale = d3.scaleOrdinal( )
      .domain( _.keys( series ) )
      .range( _.map( series, ( v, k ) => colorForSeries( k ) ) );
    const legendOrdinal = legend.legendColor()
      .labels( _.map( this.props.series, ( v, k ) => ( v.title || k ) ) )
      .classPrefix( "legend" )
      .shape( "path", d3.symbol( ).type( d3.symbolCircle ).size( 100 )( ) )
      .shapePadding( 5 )
      .scale( legendScale );
    svg.select( ".legendOrdinal" )
      .call( legendOrdinal );
  }

  render( ) {
    return (
      <div className="DateHistogram">
        <div className="chart"></div>
      </div>
    );
  }
}

DateHistogram.propTypes = {
  series: PropTypes.object
};

DateHistogram.defaultProps = {
  series: {}
};

export default DateHistogram;
