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
      metric: "observations",
      dataScaleType: "linear",
      includeUS: true,
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
    const domNode = ReactDOM.findDOMNode( this )
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
            newProperties.observations - newProperties.observations_last_year
          ) / newProperties.observations_last_year * 100;
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
    const countryPaths = g.selectAll( "path" )
      .data( worldFeatures, d => d.id )
        .attr( "fill", d => {
          if ( !d.properties[metric] ) {
            return "#000000";
          }
          return d3.interpolatePlasma( dataScale( d.properties[metric] ) );
        } );
    countryPaths
      .attr( "fill", d => {
        if ( !d.properties[metric] ) {
          return "#000000";
        }
        return d3.interpolatePlasma( dataScale( d.properties[metric] ) );
      } );
    countryPaths
      .enter( ).append( "path" )
        .attr( "id", d => d.id )
        .attr( "fill", d => {
          if ( !d.properties[metric] ) {
            return "#000000";
          }
          return d3.interpolatePlasma( dataScale( d.properties[metric] ) );
        } )
        .attr( "stroke", "rgba(255,255,255,100)" )
        .attr( "stroke-width", 0 )
        .attr( "stroke-linejoin", "round" )
        .attr( "d", path )
        .on( "click", clicked )
        .append( "title" )
          .text( d => {
            // const worldCountry = worldData[d.id];
            // if ( !worldCountry ) {
            //   return I18n.t( "unknown" );
            // }
            // const country = countriesByCode[worldCountry.iso_a2];
            if ( !d.properties.name ) {
              return I18n.t( `place_names.${_.snakeCase( d.properties.admin )}`, {
                defaultValue: d.properties.admin
              } );
            }
            return I18n.t( `place_names.${_.snakeCase( d.properties.name )}`, {
              defaultValue: d.properties.name
            } );
          } );
    countryPaths.exit( ).remove( );
    const that = this;
    function clicked( d ) {
      const current = svg.select( `[id="${d.id}"]` );
      if ( active.node( ) === current ) {
        that.setState( { currentFeatureID: null } );
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
      _.filter( worldFeatures, c => parseInt( c.properties[metric], 0 ) > 0 ),
      c => c.properties[metric] * -1
    );
    const bars = barsContainer.selectAll( ".bar" )
      .data( barData, ( d, i ) => `${metric}-${d.id}-${i}-${dataScale( d.properties[metric] )}` );
    bars.exit( ).remove( );
    const valueText = country => {
      const v = I18n.toNumber( _.round( country.properties[metric], 2 ), { precision: 0 } );
      if ( metric.match( /percent/i ) ) {
        return `${v}%`;
      }
      return v;
    };
    bars
      .style( "width", d => `${dataScale( d.properties[metric] ) * 100}%` )
      .style( "color", d => d3.color( d3.interpolatePlasma( dataScale( d.properties[metric] ) ) ).darker( 2 ) )
      .style( "background-color", d => d3.interpolatePlasma( dataScale( d.properties[metric] ) ) )
      .attr( "class", d => `bar ${currentFeatureID === d.id ? "current" : ""}` )
      .select( ".value" )
        .text( valueText );
    const enterBars = bars.enter( )
      .append( "button" )
        .attr( "class", d => `bar ${currentFeatureID === d.id ? "current" : ""}` )
        .attr( "title", d => `${d.properties.name} (${valueText( d )})` )
        .attr( "data-feature-id", d => d.id )
        .style( "width", d => `${dataScale( d.properties[metric] ) * 100}%` )
        .style( "color", d => d3.color( d3.interpolatePlasma( dataScale( d.properties[metric] ) ) ).darker( 2 ) )
        .style( "background-color", d => d3.interpolatePlasma( dataScale( d.properties[metric] ) ) )
        .on( "click", d => clicked( d ) );
    enterBars
      .append( "span" )
        .attr( "class", "rank" )
        .text( ( country, i ) => i + 1 );
    enterBars
      .append( "span" )
        .attr( "class", "place-name" )
        .text( country => {
          if ( dataScale( country.properties[metric] || 0 ) < 0.4 ) {
            return country.properties.place_code;
          }
          return I18n.t( `place_names.${_.snakeCase( country.properties.name )}`, {
            defaultValue: country.properties.name
          } );
        } );
    enterBars
      .append( "span" )
        .attr( "class", d => {
          if ( dataScale( d.properties[metric] || 0 ) < 0.5 ) {
            return "value outside";
          }
          return "value";
        } )
        .text( valueText );
    $( ".bars", domNode ).scrollTo( $( `.bars [data-feature-id=${currentFeatureID}]`, domNode ) );
  }

  renderVisualization( ) {
    const mountNode = $( ".map .chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    const svg = d3.select( mountNode ).append( "svg" );
    // const svgWidth = $( "svg", mountNode ).width( );
    const svgHeight = $( "svg", mountNode ).height( );
    svg
      .attr( "width", 960 )
      .attr( "height", 600 )
      .style( "width", "100%" )
      .style( "height", svgHeight )
      // .attr( "viewBox", `0 0 ${svgWidth} ${svgHeight}` )
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
    const { dataScaleType, includeUS } = this.state;
    return (
      <div id={id} className={`CountryGrowth ${className}`}>
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
              >
                <option value="observations">Obs in {year}</option>
                <option value="observations_last_year">Obs in {year - 1 }</option>
                <option value="difference">Growth in {year}</option>
                <option value="differencePercent">Growth in {year} (%)</option>
                <option value="percentOfTotalGrowth">% of Total Growth</option>
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
