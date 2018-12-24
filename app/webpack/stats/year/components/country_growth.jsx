/* eslint indent: 0 */

import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";
import * as topojson from "topojson-client";
import { objectToComparable } from "../../../shared/util";

class CountryGrowth extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      world: null,
      worldData: null,
      path: d3.geoPath( d3.geoNaturalEarth1( ) ),
      metric: "percentOfTotalGrowth",
      dataScaleType: "log",
      includeUS: false,
      currentFeatureID: null
    };
  }

  componentDidMount( ) {
    this.renderVisualization( );
    // d3.json( "https://unpkg.com/world-atlas@1/world/50m.json", world => this.setState( { world } ) );
    // d3.tsv( "https://unpkg.com/world-atlas@1/world/50m.tsv", worldData => this.setState( { worldData: _.keyBy( worldData, d => d.un_a3 ) } ) );
    d3.json( WORLD_ATLAS_50M_JSON_URL, world => this.setState( { world } ) );
    d3.tsv( WORLD_ATLAS_50M_TSV_URL, worldData => this.setState( { worldData: _.keyBy( worldData, d => d.iso_n3 ) } ) );
  }

  componentDidUpdate( prevProps, prevState ) {
    const { data } = this.props;
    const {
      world,
      worldData,
      metric,
      dataScaleType,
      includeUS,
      currentFeatureID
    } = this.state;
    if (
      data && world && worldData && (
        ( objectToComparable( prevProps.data ) !== objectToComparable( data ) )
        || ( prevState.world === null && world !== null )
        || ( prevState.worldData === null && worldData !== null )
        || prevState.metric !== metric
        || prevState.includeUS !== includeUS
        || prevState.dataScaleType !== dataScaleType
        || prevState.currentFeatureID !== currentFeatureID
      )
    ) {
      this.enterVisualization( );
    }
  }

  enterVisualization( ) {
    const {
      path,
      world,
      worldData,
      metric,
      dataScaleType,
      includeUS,
      currentFeatureID
    } = this.state;
    const { data: countries } = this.props;
    const countriesByCode = _.keyBy( countries, "place_code" );
    if ( !world || !worldData ) {
      return;
    }
    const domNode = ReactDOM.findDOMNode( this );
    const mountNode = $( ".map .chart", domNode ).get( 0 );
    const svg = d3.select( mountNode ).select( "svg" );
    const width = svg.attr( "width" );
    const height = svg.attr( "height" );
    const g = svg.select( "g" );
    const maxScale = 100;
    const zoom = d3.zoom( )
      .scaleExtent( [0, maxScale] )
      .on( "zoom", zoomed );
    let active = d3.select( null );
    svg.select( "rect" ).on( "click", reset );
    let worldFeatures = _.map( topojson.feature( world, world.objects.countries ).features, f => {
      let newProperties = {};
      const worldCountry = worldData[f.id];
      if ( worldCountry ) {
        newProperties = Object.assign( newProperties, worldCountry );
        const country = countriesByCode[worldCountry.iso_a2];
        if ( country ) {
          newProperties = Object.assign( newProperties, country );
          newProperties.difference = ( newProperties.observations || 0 ) - ( newProperties.observations_last_year || 0 );
          newProperties.differencePercent = (
            ( newProperties.observations || 0 ) - ( newProperties.observations_last_year || 0 )
          ) / ( newProperties.observations_last_year || 0 ) * 100;
        } else {
          // // TEST
          // newProperties.observations = 100;
          // newProperties.observations_last_year = 50;
          // newProperties.difference = newProperties.observations - newProperties.observations_last_year;
          // newProperties.differencePercent = (
          //   newProperties.observations - newProperties.observations_last_year
          // ) / newProperties.observations_last_year * 100;
        }
      }
      f.properties = Object.assign( newProperties, f.properties );
      return f;
    } );
    if ( !includeUS ) {
      worldFeatures = _.filter( worldFeatures, f => !f.properties.name.match( /United States/ ) );
    }
    const totalObs = _.reduce(
      worldFeatures,
      ( sum, f ) => ( sum + ( f.properties.observations || 0 ) ),
      0
    );
    const totalObsLastYear = _.reduce(
      worldFeatures,
      ( sum, f ) => ( sum + ( f.properties.observations_last_year || 0 ) ),
      0
    );
    const totalDifference = totalObs - totalObsLastYear;
    _.forEach( worldFeatures, ( f, i ) => {
      if ( f.properties.difference && f.properties.difference > 0 ) {
        worldFeatures[i].properties.percentOfTotalGrowth = ( f.properties.difference || 0 ) / totalDifference * 100;
      }
    } );
    const dataScale = ( dataScaleType === "linear" ? d3.scaleLinear( ) : d3.scaleLog( ) )
      .domain( [1, d3.max( _.map( worldFeatures, d => parseInt( d.properties[metric], 0 ) ) )] );
    const colorizer = d => {
      if ( parseInt( d.properties[metric], 0 ) <= 0 ) {
        return "#000000";
      }
      return d3.interpolateViridis( dataScale( d.properties[metric] ) );
    };
    const valueText = ( country, options = { } ) => {
      const noBar = options.noBar === true;
      let precision = 0;
      if ( metric.match( /percent/i ) ) {
        precision = 2;
      }
      let v = I18n.toNumber( country.properties[metric], { precision } );
      if ( !noBar && dataScale( country.properties[metric] ) < 0.4 ) {
        v = `${country.properties.name} ${v}`;
      }
      if ( metric.match( /percent/i ) ) {
        if ( country.properties[metric] === Infinity ) {
          return "infinity%";
        }
        if ( _.isNaN( country.properties[metric] ) || _.isUndefined( country.properties[metric] ) ) {
          return "0%";
        }
        return `${v}%`;
      }
      if ( _.isNaN( country.properties[metric] ) || _.isUndefined( country.properties[metric] ) ) {
        return "0";
      }
      return v;
    };
    const pathTitle = d => {
      let text = I18n.t( `place_names.${_.snakeCase( d.properties.name )}`, {
        defaultValue: d.properties.name
      } );
      if ( !d.properties.name ) {
        text = I18n.t( `place_names.${_.snakeCase( d.properties.admin )}`, {
          defaultValue: d.properties.admin
        } );
      }
      text = `${text} (${valueText( d, { noBar: true } )})`;
      return text;
    };
    const countryPaths = g.selectAll( "path" )
      .data( worldFeatures, d => d.id )
        .attr( "fill", colorizer );
    countryPaths
      .attr( "fill", colorizer )
      .select( "title" )
        .text( pathTitle );
    countryPaths
      .enter( ).append( "path" )
        .attr( "id", d => d.id )
        .attr( "fill", colorizer )
        .attr( "stroke", "rgba(255,255,255,100)" )
        .attr( "stroke-width", 0 )
        .attr( "stroke-linejoin", "round" )
        .attr( "d", path )
        .on( "click", clicked )
        .append( "title" )
          .text( pathTitle );
    countryPaths.exit( ).remove( );
    const that = this;
    function clicked( d ) {
      const current = svg.select( `[id="${d.id}"]` );
      if ( that.state.currentFeatureID === d.id ) {
        return reset( );
      }
      that.setState( { currentFeatureID: d.id } );
      active.classed( "active", false );
      active = current.classed( "active", true );
      const bounds = path.bounds( d );
      const boundsWidth = bounds[1][0] - bounds[0][0];
      const boundsHeight = bounds[1][1] - bounds[0][1];
      const boundsCenterX = ( bounds[0][0] + bounds[1][0] ) / 2;
      const boundsCenterY = ( bounds[0][1] + bounds[1][1] ) / 2;
      const maxDimRatio = Math.max( boundsWidth / width, boundsHeight / height );
      const maxCurrentScale = Math.min( maxScale, 0.9 / maxDimRatio );
      const scale = Math.max( 1, maxCurrentScale );
      const translate = [width / 2 - scale * boundsCenterX, height / 2 - scale * boundsCenterY];
      svg.transition()
        .duration( 1000 )
        .call( zoom.transform, d3.zoomIdentity.translate( translate[0], translate[1] ).scale( scale ) );
    }
    function reset() {
      that.setState( { currentFeatureID: null } );
      active.classed( "active", false );
      active = d3.select( null );
      svg.transition( )
        .duration( 750 )
        .call( zoom.transform, d3.zoomIdentity );
    }
    function zoomed() {
      g.style( "stroke-width", `${0.5 / d3.event.transform.k}px` );
      g.attr( "transform", d3.event.transform );
    }

    const barsContainer = d3.select( $( ".bars .chart", domNode ).get( 0 ) );
    const barData = _.sortBy(
      _.uniqBy(
        _.filter( worldFeatures, c => parseInt( c.properties[metric], 0 ) > 0 ),
        c => c.properties.iso_a2
      ),
      c => c.properties[metric] * -1
    );
    const bars = barsContainer.selectAll( ".bar" )
      .data( barData, ( d, i ) => `${metric}-${d.id}-${i}-${dataScale( d.properties[metric] )}` );
    bars.exit( ).remove( );
    const nameText = country => {
      if ( dataScale( country.properties[metric] || 0 ) < 0.4 ) {
        // return country.properties.place_code;
        return "";
      }
      return I18n.t( `place_names.${_.snakeCase( country.properties.name )}`, {
        defaultValue: country.properties.name
      } );
    };
    const valueClass = d => {
      if ( dataScale( d.properties[metric] || 0 ) < 0.8 ) {
        return "value outside";
      }
      return "value";
    };
    const updateBars = bars
      .style( "width", d => `${dataScale( d.properties[metric] ) * 100}%` )
      .style( "color", d => d3.color( d3.interpolateViridis( dataScale( d.properties[metric] ) ) ).darker( 2 ) )
      .style( "background-color", d => d3.interpolateViridis( dataScale( d.properties[metric] ) ) )
      .attr( "class", d => `bar ${currentFeatureID === d.id ? "current expand" : ""} ${barData.length < 50 ? "expand" : ""}` );
    updateBars
      .select( ".value" )
        .text( valueText )
        .attr( "class", valueClass );
    updateBars
      .select( ".place-name" )
        .text( nameText );
    const enterBars = bars.enter( )
      .append( "button" )
        .attr( "class", d => `bar ${currentFeatureID === d.id ? "current expand" : ""} ${barData.length < 50 ? "expand" : ""}` )
        .attr( "title", d => `${d.properties.name} (${valueText( d, { noBar: true } )})` )
        .attr( "data-feature-id", d => d.id )
        .style( "width", d => `${dataScale( d.properties[metric] ) * 100}%` )
        .style( "color", d => d3.color( d3.interpolateViridis( dataScale( d.properties[metric] ) ) ).darker( 2 ) )
        .style( "background-color", d => d3.interpolateViridis( dataScale( d.properties[metric] ) ) )
        .on( "click", d => clicked( d ) );
    enterBars
      .append( "span" )
        .attr( "class", "rank" )
        .text( ( country, i ) => i + 1 );
    enterBars
      .append( "span" )
        .attr( "class", "place-name" )
        .text( nameText );
    enterBars
      .append( "span" )
        .attr( "class", valueClass )
        .text( valueText );
    $( ".bars", domNode ).scrollTo( $( `.bars [data-feature-id=${currentFeatureID}]`, domNode ) );
  }

  renderVisualization( ) {
    const mountNode = $( ".map .chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const svg = d3.select( mountNode ).append( "svg" );
    const svgHeight = $( "svg", mountNode ).height( );
    svg
      .attr( "width", 960 )
      .attr( "height", 600 )
      .style( "width", "100%" )
      .style( "height", svgHeight )
      .attr( "viewBox", `0 0 960 ${svgHeight}` )
      .attr( "preserveAspectRatio", "xMidYMid meet" );
    svg.append( "rect" )
      .attr( "class", "background" )
      .attr( "width", 960 )
      .attr( "height", 600 )
      .attr( "fill", "transparent" );
    svg.append( "g" );
  }

  render( ) {
    const { id, className, year } = this.props;
    const { dataScaleType, includeUS, metric } = this.state;
    window.d3 = d3;
    return (
      <div id={id} className={`CountryGrowth ${className}`}>
        <h3><span>Growth By Country</span></h3>
        <p className="text-muted">
          
          Where is growth happening? This map and chart attempt to break this
          down by country, which turns out to be complicated because growth by
          country can be very imbalanced. Here we've chosen to omit the United
          States and use a log scale by default to accentuate differences
          between other countries. If a country is black that means it did not
          contribute signicantly to a percentage, or it had no growth this year,
          or did not have more observations this year than last year. <strong>"%
          of total growth"</strong> means how much of worldwide growth was from
          a particular country, e.g. if there were 20 observations in 2018 and
          10 in 2017, that would be 10 observations of growth, and if 5 of those
          observations were from Benin, then Benin contributed 50% of total
          growth. <strong>"% growth"</strong> means the number of observations
          this year as a percent of last year, so if there were 10 observations
          in Laos last year but 20 this year, that would be 100% growth.

        </p>
        <div className="row">
          <div className="map col-xs-9">
            <div className="chart" />
          </div>
          <div className="bars col-xs-3">
            <div className="controls">
              <select
                className="form-control stacked"
                onChange={e => {
                  this.setState( { metric: e.target.value } );
                }}
                value={metric}
              >
                <option value="percentOfTotalGrowth">% of Total Growth</option>
                <option value="differencePercent">% Growth in {year}</option>
                <option value="difference">Growth in {year} (obs)</option>
                <option value="observations">Obs in {year}</option>
                <option value="observations_last_year">Obs in {year - 1 }</option>
              </select>
              <label htmlFor="CountryGrowth-include-us">
                <input
                  id="CountryGrowth-include-us"
                  type="checkbox"
                  checked={includeUS}
                  onChange={( ) => {
                    this.setState( { includeUS: !includeUS } );
                  }}
                />
                { " " }
                Include US
              </label>
              <div>
                Scale:
                { " " }
                <label htmlFor="CountryGrowth-data-scale-type-linear">
                  <input
                    id="CountryGrowth-data-scale-type-linear"
                    type="radio"
                    value="linear"
                    checked={dataScaleType === "linear"}
                    onChange={e => {
                      this.setState( { dataScaleType: e.target.value } );
                    }}
                  />
                  { " " }
                  Linear
                </label>
                { " " }
                <label htmlFor="CountryGrowth-data-scale-type-log">
                  <input
                    id="CountryGrowth-data-scale-type-log"
                    type="radio"
                    value="log"
                    checked={dataScaleType === "log"}
                    onChange={e => {
                      this.setState( { dataScaleType: e.target.value } );
                    }}
                  />
                  { " " }
                  Log
                </label>
              </div>
            </div>
            <div className="chart" />
          </div>
        </div>
      </div>
    );
  }
}

CountryGrowth.propTypes = {
  className: PropTypes.string,
  id: PropTypes.string,
  data: PropTypes.array,
  year: PropTypes.number
};

export default CountryGrowth;
