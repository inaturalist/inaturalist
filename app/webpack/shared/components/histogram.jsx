/* eslint indent: 0 */

import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";
import d3tip from "d3-tip";
import legend from "d3-svg-legend";
import { objectToComparable, shortFormattedNumber } from "../util";

class Histogram extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      width: null,
      height: null,
      x: null,
      y: null,
      clipID: null,
      tip: null,
      color: d3.scaleOrdinal( d3.schemeCategory10 )
    };
  }

  componentDidMount( ) {
    this.renderHistogram( );
  }

  shouldComponentUpdate( nextProps ) {
    const { series } = this.props;
    const shouldUpdate = objectToComparable( nextProps.series ) !== objectToComparable( series );
    return shouldUpdate;
  }

  componentDidUpdate( prevProps ) {
    const { series } = this.props;
    const shouldUpdateSeries = objectToComparable( prevProps.series ) !== objectToComparable( series );
    if ( shouldUpdateSeries ) {
      this.enterSeries( );
    }
  }

  colorForSeries( seriesName ) {
    const { series } = this.props;
    const { color } = this.state;
    if ( series[seriesName] && series[seriesName].color ) {
      return series[seriesName].color;
    }
    return color( seriesName );
  }

  // This is a kludge to deal with the fact that we're not using a modern
  // (>= 5.0) version of d3, where we could do this by calling
  // d3.axisLeft( y ).tickFormat( "~s" )
  axisLeft( y ) {
    const { tickFormatLeft } = this.props;
    const axisLeft = d3.axisLeft( y );
    if ( tickFormatLeft ) {
      return axisLeft.tickFormat( tickFormatLeft );
    }
    return axisLeft.tickFormat( shortFormattedNumber );
  }

  enterSeries( newState = {} ) {
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const svg = d3.select( mountNode ).select( "svg" );
    const {
      series,
      onClick,
      xAttr,
      xParser,
      yExtent
    } = this.props;
    const {
      width,
      height,
      x,
      y,
      clipID,
      tip
    } = Object.assign( {}, this.state, newState );
    if ( !x ) {
      return;
    }
    // const parseTime = date => moment( date ).toDate( );
    const localSeries = {};
    _.forEach( series, ( s, seriesName ) => {
      localSeries[seriesName] = _.map( s.data, d => Object.assign( {}, d, {
        [xAttr]: xParser ? xParser( d[xAttr] ) : d[xAttr],
        value: d.value,
        offset: d.offset,
        seriesName
      } ) );
    } );
    const combinedData = _.flatten( _.values( localSeries ) );
    if ( yExtent ) {
      y.domain( yExtent );
    } else {
      y.domain( [0, d3.max( combinedData, d => d.value + ( d.offset || 0 ) )] );
    }
    const line = d3.line( )
      .x( d => x( d[xAttr] ) )
      .y( d => y( d.value ) );
    const focus = svg.select( ".focus" );
    const seriesGroups = focus.selectAll( ".series" ).data( _.keys( localSeries ), d => d );
    seriesGroups.enter( )
      .append( "g" )
        .attr( "style", `clip-path: url(#${clipID})` )
        .attr( "class", d => `series ${_.snakeCase( d )}` );
    seriesGroups.exit( ).remove( );
    _.forEach( localSeries, ( seriesData, seriesName ) => {
      const seriesGroup = focus.select( `.${_.snakeCase( seriesName )}` );
      const colorForDatum = d => {
        const color = this.colorForSeries( seriesName );
        return d.highlight ? d3.color( color ).brighter( 1.5 ) : color;
      };
      if ( series[seriesName].style === "bar" ) {
        const barWidth = ( d, i ) => {
          let nextX = width;
          if ( seriesData[i + 1] ) {
            nextX = x( seriesData[i + 1][xAttr] );
          } else if ( seriesData[i - 1] ) {
            return x( d[xAttr] ) - x( seriesData[i - 1][xAttr] );
          }
          return nextX - x( d[xAttr] );
        };
        const barHeight = d => {
          const h = height - y( d.value );
          if ( d.value > 0 && h < 1 ) {
            return 1;
          }
          return h;
        };
        const bars = seriesGroup.selectAll( "rect" ).data( seriesData );
        // update selection, these things happens when the data changes
        bars
          .attr( "width", barWidth )
          .attr( "height", barHeight )
          .attr( "fill", colorForDatum )
          .attr( "transform", d => {
            if ( d.offset ) {
              return `translate( ${x( d[xAttr] )}, ${y( d.value + d.offset )} )`;
            }
            return `translate( ${x( d[xAttr] )}, ${y( d.value )} )`;
          } );
        const barsEnter = bars.enter( )
            .append( "rect" )
              .attr( `data-${xAttr}`, d => d[xAttr].toString( ) )
              .attr( "width", barWidth )
              .attr( "height", barHeight )
              .attr( "transform", d => {
                if ( d.offset ) {
                  return `translate( ${x( d[xAttr] )}, ${y( d.value + d.offset )} )`;
                }
                return `translate( ${x( d[xAttr] )}, ${y( d.value )} )`;
              } )
              .attr( "fill", colorForDatum )
              .on( "mouseover", tip.show )
              .on( "mouseout", tip.hide );
        bars.exit( ).remove( );
        if ( onClick ) {
          barsEnter.on( "click", onClick ).style( "cursor", "pointer" );
        }
      } else {
        seriesGroup.append( "path" ).datum( seriesData )
            .attr( "fill", "none" )
            .attr( "stroke", this.colorForSeries( seriesName ) )
            .attr( "stroke-linejoin", "round" )
            .attr( "stroke-linecap", "round" )
            .attr( "stroke-width", 1.5 )
            .attr( "d", line );
        const points = seriesGroup.selectAll( "circle" ).data( seriesData )
          .enter().append( "circle" )
            .attr( "cx", d => x( d[xAttr] ) )
            .attr( "cy", d => y( d.value ) )
            .attr( "r", 2 )
            .attr( "fill", "white" )
            .style( "stroke", colorForDatum )
            .on( "mouseover", tip.show )
            .on( "mouseout", tip.hide );
        if ( onClick ) {
          points.on( "click", onClick ).style( "cursor", "pointer" );
        }
      }
    } );
    const legendScale = d3.scaleOrdinal( )
      .domain( _.keys( localSeries ) )
      .range( _.map( localSeries, ( v, k ) => this.colorForSeries( k ) ) );
    const legendOrdinal = legend.legendColor( )
      .labels( _.map( series, ( v, k ) => ( v.title || k ) ) )
      .classPrefix( "legend" )
      .shape( "path", d3.symbol( ).type( d3.symbolCircle ).size( 100 )( ) )
      .scale( legendScale );
    svg.select( ".legendOrdinal" )
      .call( legendOrdinal );
    focus.select( ".axis--y" )
      .call( this.axisLeft( y ) )
      .select( ".domain" )
        .remove( );
    // This doesn't quite higlight the fill color of the rects in the context
    // if ( showContext ) {
    //   const context = d3.select( mountNode ).selectAll( ".context" );
    //   const contextSeriesName = _.keys( localSeries )[0];
    //   const contextSeriesData = localSeries[contextSeriesName];
    //   const contextBars = context.selectAll( "rect" ).data( contextSeriesData );
    //   const colorForDatum = d => {
    //     const color = this.colorForSeries( contextSeriesName );
    //     return d.highlight ? d3.color( color ).brighter( 1.5 ) : color;
    //   };
    //   contextBars.enter( )
    //     .append( "rect" )
    //       .attr( "fill", colorForDatum );
    // }
    this.setState( { x, y } );
  }

  rescaleSeries( newState ) {
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const { series, xParser, xAttr } = this.props;
    const localSeries = {};
    // const parseTime = date => moment( date ).toDate( );
    const {
      width,
      x,
      y
    } = Object.assign( {}, this.state, newState );
    if ( !x ) {
      return;
    }
    _.forEach( series, ( s, seriesName ) => {
      localSeries[seriesName] = _.map( s.data, d => Object.assign( {}, d, {
        [xAttr]: xParser ? xParser( d[xAttr] ) : xAttr,
        value: d.value,
        offset: d.offset,
        seriesName
      } ) );
    } );
    _.forEach( localSeries, ( seriesData, seriesName ) => {
      const seriesClass = _.snakeCase( seriesName );
      d3.select( mountNode ).selectAll( `.focus .${seriesClass} rect` )
        .attr( "width", ( d, i ) => {
          let nextX = width;
          if ( seriesData[i + 1] ) {
            nextX = x( seriesData[i + 1][xAttr] );
          }
          return Math.max( nextX - x( d[xAttr] ), 0 );
        } )
        .attr( "transform", d => {
          if ( d.offset ) {
            return `translate( ${x( d[xAttr] )}, ${y( d.value + d.offset )} )`;
          }
          return `translate( ${x( d[xAttr] )}, ${y( d.value )} )`;
        } );
    } );
  }

  renderGuides( newState ) {
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const svg = d3.select( mountNode ).select( "svg" );
    const { guides } = this.props;
    const {
      x,
      y,
      clipID
    } = Object.assign( {}, this.state, newState );
    if ( !guides ) {
      return;
    }
    const focus = svg.select( ".focus" );
    const guideGroups = focus.selectAll( ".guides" ).data( guides );
    const xRangeMin = x.range( )[0];
    const xRangeMax = x.range( )[1];
    const yRangeMin = y.range( )[0];
    const yRangeMax = y.range( )[1];
    const guideLineGroups = guideGroups.enter( )
      .append( "g" )
        .attr( "style", `clip-path: url(#${clipID})` )
        .attr( "class", "guide" );
    guideLineGroups
      .append( "line" )
        .attr( "stroke-width", 1 )
        .attr( "stroke", guide => guide.color || "white" )
        .attr( "stroke-dasharray", guide => guide.dasharray )
        .attr( "opacity", guide => guide.opacity )
        .attr( "x1", guide => (
          guide.axis === "x" ? x( guide.value ) : xRangeMin
        ) )
        .attr( "x2", guide => (
          guide.axis === "x" ? x( guide.value ) : xRangeMax
        ) )
        .attr( "y1", guide => (
          guide.axis === "x" ? yRangeMin : y( guide.value )
        ) )
        .attr( "y2", guide => (
          guide.axis === "x" ? yRangeMax : y( guide.value )
        ) );
    const otherOffset = 5;
    guideLineGroups
      .append( "text" )
        .attr( "fill", "white" )
        .attr( "text-anchor", guide => guide.textAnchor || "start" )
        .attr( "x", guide => {
          if ( guide.axis === "x" ) return x( guide.value ) + ( guide.offset || 0 );
          return guide.textAnchor === "end" ? xRangeMax - otherOffset : xRangeMin + otherOffset;
        } )
        .attr( "y", guide => {
          if ( guide.axis === "x" ) {
            return guide.textAnchor === "end" ? yRangeMax - otherOffset : yRangeMin + otherOffset;
          }
          return y( guide.value ) + ( guide.offset || 0 );
        } )
        .text( guide => guide.label );
  }

  renderHistogram( ) {
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const {
      series,
      xExtent,
      xAttr,
      xFormatter,
      xParser,
      yExtent,
      tickFormatBottom,
      legendPosition,
      showContext,
      id,
      margin: propMargin
    } = this.props;
    $( mountNode ).html( "" );
    const svg = d3.select( mountNode ).append( "svg" );
    const svgWidth = $( "svg", mountNode ).width( );
    const svgHeight = $( "svg", mountNode ).height( );
    svg
      .attr( "width", svgWidth )
      .attr( "height", svgHeight )
      .attr( "viewBox", `0 0 ${svgWidth} ${svgHeight}` )
      .attr( "preserveAspectRatio", "xMidYMid meet" );
    const margin = Object.assign( { }, Histogram.defaultProps.margin, propMargin );
    const width = $( "svg", mountNode ).width( ) - margin.left - margin.right;
    const height2 = 50;
    const space = 50;
    let height = $( "svg", mountNode ).height( ) - margin.top - margin.bottom;
    if ( showContext ) {
      height -= height2;
    }
    const margin2 = {
      top: height + space,
      right: 20,
      bottom: 30,
      left: 50
    };
    const clipID = `clip-${id}-${( new Date( ) ).getTime( )}`;
    svg.append( "defs" ).append( "clipPath" )
        .attr( "id", clipID )
      .append( "rect" )
        .attr( "width", width )
        .attr( "height", height );
    const g = svg.append( "g" )
      .attr( "class", "focus" )
      .attr( "transform", `translate(${margin.left}, ${margin.top})` );
    let context;
    if ( showContext ) {
      context = svg.append( "g" )
        .attr( "class", "context" )
        .attr( "transform", `translate(${margin2.left}, ${margin2.top})` );
    }

    // const parseTime = date => moment( date ).toDate( );
    const localSeries = {};
    _.forEach( series, ( s, seriesName ) => {
      localSeries[seriesName] = _.map( s.data, d => Object.assign( {}, d, {
        [xAttr]: xParser ? xParser( d[xAttr] ) : d[xAttr],
        value: d.value,
        offset: d.offset,
        seriesName
      } ) );
    } );
    const x = xAttr === "date"
      ? d3.scaleTime( ).rangeRound( [0, width] )
      : d3.scaleLinear( ).rangeRound( [0, width] );
    const y = d3.scaleLinear( ).rangeRound( [height, 0] );

    const combinedData = _.flatten( _.values( localSeries ) );
    if ( xExtent && !showContext ) {
      x.domain( xExtent );
    } else {
      x.domain( d3.extent( combinedData, d => d[xAttr] ) );
    }
    if ( yExtent ) {
      y.domain( yExtent );
    } else {
      y.domain( [0, d3.max( combinedData, d => d.value + ( d.offset || 0 ) )] );
    }

    let axisBottom = d3.axisBottom( x );
    if ( tickFormatBottom ) {
      axisBottom = axisBottom.tickFormat( tickFormatBottom );
    }

    g.append( "g" )
      .attr( "transform", `translate(0,${height})` )
      .attr( "class", "axis--x" )
      .call( axisBottom )
      .select( ".domain" )
        .remove();

    g.append( "g" )
      .attr( "class", "axis--y" )
      .call( this.axisLeft( y ) )
      .select( ".domain" )
        .remove( );

    // const dateFormatter = d3.timeFormat( "%d %b" );
    const tip = d3tip()
      .attr( "class", "d3-tip" )
      .offset( [-10, 0] )
      .html( d => {
        const { series: currentSeries } = this.props;
        if ( currentSeries[d.seriesName] && currentSeries[d.seriesName].label ) {
          return currentSeries[d.seriesName].label( d );
        }
        return I18n.t( "bold_label_colon_value_html", {
          label: xFormatter( d[xAttr] ),
          value: I18n.toNumber( d.value, { precision: 0 } )
        } );
      } );
    svg.call( tip );

    const newState = {
      width,
      height,
      x,
      y,
      clipID,
      tip
    };

    svg.append( "g" )
      .attr( "class", "legendOrdinal" )
      .attr( "transform", ( ) => {
        if ( legendPosition.indexOf( "translate" ) >= 0 ) {
          return legendPosition;
        }
        if ( legendPosition === "nw" ) {
          return "translate(70,20)";
        }
        return `translate(${width - 20},20)`;
      } );
    this.setState( newState );
    this.enterSeries( newState );
    this.renderGuides( newState );

    // Zoom and Brush
    if ( showContext ) {
      const x2 = d3.scaleTime( ).rangeRound( [0, width] );
      const y2 = d3.scaleLinear( ).rangeRound( [height2, 0] );
      x2.domain( d3.extent( combinedData, d => d[xAttr] ) );
      y2.domain( d3.extent( combinedData, d => d.value ) );
      const focus = g;
      const zoomed = ( ) => {
        if ( d3.event.sourceEvent && d3.event.sourceEvent.type === "brush" ) return; // ignore zoom-by-brush
        const t = d3.event.transform;
        x.domain( t.rescaleX( x2 ).domain( ) );
        this.setState( { x } );
        this.rescaleSeries( );
        focus.select( ".axis--x" ).call( axisBottom );
        context.select( ".brush" ).call( brush.move, x.range( ).map( t.invertX, t ) );
      };
      const zoom = d3.zoom( )
        .scaleExtent( [1, Infinity] )
        .translateExtent( [[0, 0], [width, height]] )
        .extent( [[0, 0], [width, height]] )
        .on( "zoom", zoomed );
      const brushed = ( ) => {
        if ( d3.event.sourceEvent && d3.event.sourceEvent.type === "zoom" ) return; // ignore brush-by-zoom
        const s = d3.event.selection || x2.range();
        x.domain( s.map( x2.invert, x2 ) );
        this.setState( { x } );
        this.rescaleSeries( { x, y } );
        focus.select( ".axis--x" ).call( axisBottom );
        svg.select( ".zoom" ).call(
          zoom.transform,
          d3.zoomIdentity.scale( width / ( s[1] - s[0] ) ).translate( -s[0], 0 )
        );
      };
      const brush = d3.brushX( )
        .extent( [[0, 0], [width, height2]] )
        .on( "brush end", brushed );
      const contextSeriesName = _.keys( localSeries )[0];
      const contextSeriesData = localSeries[contextSeriesName];
      const contextBars = context.selectAll( "rect" ).data( contextSeriesData );
      const colorForDatum = d => {
        const color = this.colorForSeries( contextSeriesName );
        return d.highlight ? d3.color( color ).brighter( 1.5 ) : color;
      };
      contextBars
        .enter( ).append( "rect" )
          .attr( "width", ( d, i ) => {
            let nextX = width;
            if ( contextSeriesData[i + 1] ) {
              nextX = x( contextSeriesData[i + 1][xAttr] );
            }
            return nextX - x( d[xAttr] );
          } )
          .attr( "height", d => height2 - y2( d.value ) )
          .attr( "fill", colorForDatum )
          .attr( "transform", d => {
            if ( d.offset ) {
              return `translate( ${x( d[xAttr] )}, ${y2( d.value + d.offset )} )`;
            }
            return `translate( ${x( d[xAttr] )}, ${y2( d.value )} )`;
          } );
      let defaultBrushRange = x.range( );
      if ( xExtent ) {
        defaultBrushRange = [
          Math.max( x( xExtent[0] ), x.range( )[0] ),
          Math.min( x( xExtent[1] ), x.range( )[1] )
        ];
      }
      contextBars
        .call( brush )
        .call( brush.move, defaultBrushRange );
      context.append( "g" )
        .attr( "class", "brush" )
        .call( brush )
        .call( brush.move, defaultBrushRange );
      // If you enable zoom on the context chart, you lose other interactive elements like tips
      // svg.append( "rect" )
      //   .attr( "id", "zoom" )
      //   .attr( "class", "zoom" )
      //   .attr( "width", width )
      //   .attr( "height", height )
      //   .attr( "transform", `translate(${margin.left},${margin.top})` )
      //   .call( zoom );
      // END zoom and brush
    }
  }

  render( ) {
    const { id, className } = this.props;
    return (
      <div id={id} className={`Histogram ${className}`}>
        <div className="chart" />
      </div>
    );
  }
}

Histogram.propTypes = {
  series: PropTypes.object,
  tickFormatBottom: PropTypes.func,
  tickFormatLeft: PropTypes.func,
  onClick: PropTypes.func,
  xExtent: PropTypes.array,
  yExtent: PropTypes.array,
  legendPosition: PropTypes.string,
  showContext: PropTypes.bool,
  className: PropTypes.string,
  id: PropTypes.string,
  margin: PropTypes.shape( {
    top: PropTypes.number,
    right: PropTypes.number,
    bottom: PropTypes.number,
    left: PropTypes.number
  } ),
  guides: PropTypes.arrayOf( PropTypes.shape( {
    axis: PropTypes.oneOf( ["x", "y"] ),
    value: PropTypes.node,
    className: PropTypes.string,
    label: PropTypes.string,
    // Whether to anchor the label at the start or the end of the guide
    textAnchor: PropTypes.oneOf( ["start", "end"] ),
    // How much to offset the label from the guide
    offset: PropTypes.number
  } ) ),
  // Name of the attribute for the x axis in each datum
  xAttr: PropTypes.string.isRequired,
  // If the data comes in as a string but needs some processing, each datum will
  // get transformed by this function
  xParser: PropTypes.func,
  xFormatter: PropTypes.func
};

Histogram.defaultProps = {
  series: {},
  legendPosition: "ne",
  margin: {
    top: 20,
    right: 20,
    bottom: 30,
    left: 50
  },
  xFormatter: x => x.toString( )
};

export default Histogram;
