/* eslint indent: 0 */

// Adapted from https://bl.ocks.org/iamkevinv/0a24e9126cd2fa6b283c6f2d774b69a2

/* global WORLD_ATLAS_50M_JSON_URL */
/* global WORLD_ATLAS_50M_TSV_URL */

import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";
import * as topojson from "topojson-client";
import { objectToComparable } from "../../../shared/util";

class CountryGrowth extends React.Component {
  static resetVisualization( ) {
    // Rather silly way of triggering the d3 visualizations internal reset
    // function
    d3.select( ".CountryGrowth .map .chart rect" ).dispatch( "click" );
  }

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
    d3.json( WORLD_ATLAS_50M_JSON_URL ).then( world => this.setState( { world } ) );
    d3.tsv( WORLD_ATLAS_50M_TSV_URL ).then(
      worldData => this.setState( { worldData: _.keyBy( worldData, d => d.iso_n3 ) } )
    );
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
      // Try to reset on first load, but definitely don't reset if there's a
      // selected feature
      if ( data && !prevState.data && !currentFeatureID ) {
        CountryGrowth.resetVisualization( );
      }
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
    const g = svg.select( "g" );
    const maxScale = 100;
    const zoom = d3.zoom( )
      .scaleExtent( [0, maxScale] )
      .on( "zoom", zoomed );
    let active = d3.select( null );
    let worldFeatures = _.map( topojson.feature( world, world.objects.countries ).features, f => {
      let newProperties = {};
      if ( f.id === "-99" ) return f;
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
      worldFeatures = _.filter( worldFeatures, f => !( f.properties.name && f.properties.name.match( /United States/ ) ) );
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
    const translatedPlaceName = d => I18n.t( `places_name.${_.snakeCase( d.properties.name )}`, {
      defaultValue: (
        I18n.t( `places_name.${_.snakeCase( d.properties.admin )}`, {
          defaultValue: d.properties.name || d.properties.admin || I18n.t( "unknown" )
        } )
      )
    } );
    const valueText = ( country, options = { } ) => {
      const noBar = options.noBar === true;
      let precision = 0;
      if ( metric.match( /percent/i ) ) {
        precision = 2;
      }
      let v = I18n.toNumber( country.properties[metric], { precision } );
      if ( !noBar && dataScale( country.properties[metric] ) < 0.4 ) {
        v = `${translatedPlaceName( country )} ${v}`;
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
    const pathTitle = d => `${translatedPlaceName( d )} (${valueText( d, { noBar: true } )})`;
    const countryPaths = g.selectAll( "path" )
      .data( worldFeatures, d => d.id )
        .attr( "fill", colorizer );
    countryPaths
      .attr( "fill", colorizer )
      .attr( "class", d => ( d.id === currentFeatureID ? "current" : "" ) )
      .select( "title" )
        .text( pathTitle );
    countryPaths
      .enter( ).append( "path" )
        .attr( "id", d => d.id )
        .attr( "class", d => ( d.id === currentFeatureID ? "current" : "" ) )
        .attr( "fill", colorizer )
        .attr( "stroke", "rgba(255,255,255,100)" )
        .attr( "stroke-linejoin", "round" )
        .attr( "d", path )
        .on( "click", clicked )
        .append( "title" )
          .text( pathTitle );
    countryPaths.exit( ).remove( );
    const that = this;
    function zoomToBounds( bounds ) {
      const svgWidth = $( "svg", domNode ).width( );
      const svgHeight = $( "svg", domNode ).height( );
      const boundsWidth = bounds[1][0] - bounds[0][0];
      const boundsHeight = bounds[1][1] - bounds[0][1];
      const boundsCenterX = ( bounds[0][0] + bounds[1][0] ) / 2;
      const boundsCenterY = ( bounds[0][1] + bounds[1][1] ) / 2;
      const maxDimRatio = Math.max( boundsWidth / svgWidth, boundsHeight / svgHeight );
      const maxCurrentScale = Math.min( maxScale, 0.5 / maxDimRatio );
      const newScale = Math.max( 0.01, maxCurrentScale );
      const translate = [
        svgWidth / 2 - newScale * boundsCenterX,
        svgHeight / 2 - newScale * boundsCenterY
      ];
      svg.transition( )
        .duration( 1000 )
        .call(
          zoom.transform,
          d3.zoomIdentity.translate( translate[0], translate[1] ).scale( newScale )
        );
    }
    function reset() {
      that.setState( { currentFeatureID: null } );
      active.classed( "active", false );
      active = d3.select( null );
      const projection = path.projection( );
      const ne = projection( [179, 89] );
      const sw = projection( [-179, -89] );
      const bounds = [sw, ne];
      zoomToBounds( bounds );
    }
    svg.select( "rect" ).on( "click", reset );
    function zoomed( zoomEvent ) {
      g.selectAll( "path" ).style( "stroke-width", "0px" );
      g.selectAll( ".current" ).style( "stroke-width", `${1.5 / zoomEvent.transform.k}px` );
      g.attr( "transform", zoomEvent.transform );
    }
    function clicked( _clickEvent, d ) {
      const current = svg.selectAll( `[id="${d.id}"]` );
      if ( that.state.currentFeatureID === d.id ) {
        return reset( );
      }
      that.setState( { currentFeatureID: d.id } );
      active.classed( "active", false );
      active = current.classed( "active", true );
      let bounds = path.bounds( d );
      // prefer iNat bounds when available
      if ( d.properties.place_bounding_box ) {
        const projection = path.projection( );
        const swlat = parseFloat( d.properties.place_bounding_box[0], 0 );
        const swlng = parseFloat( d.properties.place_bounding_box[1], 0 );
        const nelat = parseFloat( d.properties.place_bounding_box[2], 0 );
        const nelng = parseFloat( d.properties.place_bounding_box[3], 0 );
        let ne = projection( [nelng, nelat] );
        let sw = projection( [swlng, swlat] );
        // if the bounding box straddles the date line
        if ( swlng > 0 && nelng < 0 ) {
          // if it's more to the west of the dateline than to the east
          if ( 0 - swlng > nelng ) {
            // set ne corner to just about 180`
            ne = projection( [179.999, nelat] );
          } else {
            // set sw corner to just about -180
            sw = projection( [-179.9999, swlat] );
          }
        }
        bounds = [sw, ne];
      }
      zoomToBounds( bounds );
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
        return "";
      }
      return translatedPlaceName( country );
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
        .attr( "title", d => `${translatedPlaceName( d )} (${valueText( d, { noBar: true } )})` )
        .attr( "data-feature-id", d => d.id )
        .style( "width", d => `${dataScale( d.properties[metric] ) * 100}%` )
        .style( "color", d => d3.color( d3.interpolateViridis( dataScale( d.properties[metric] ) ) ).darker( 2 ) )
        .style( "background-color", d => d3.interpolateViridis( dataScale( d.properties[metric] ) ) )
        .on( "click", ( clickEvent, d ) => clicked( clickEvent, d ) );
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
    const svgWidth = $( "svg", mountNode ).width( );
    const svgHeight = $( "svg", mountNode ).height( );
    svg
      .attr( "width", svgWidth )
      .attr( "height", svgHeight )
      .style( "width", "100%" )
      .style( "height", svgHeight )
      .attr( "viewBox", `0 0 ${svgWidth} ${svgHeight}` )
      .attr( "preserveAspectRatio", "xMidYMid meet" );
    svg.append( "rect" )
      .attr( "class", "background" )
      .attr( "width", svgWidth )
      .attr( "height", svgHeight )
      .attr( "fill", "transparent" );
    svg.append( "g" );
  }

  render( ) {
    const { id, className, year } = this.props;
    const {
      currentFeatureID,
      dataScaleType,
      includeUS,
      metric
    } = this.state;
    window.d3 = d3;
    return (
      <div id={id} className={`CountryGrowth ${className}`}>
        <h3>
          <a name="country-growth" href="#country-growth">
            <span>{ I18n.t( "views.stats.year.growth_by_country_title" ) }</span>
          </a>
        </h3>
        <p
          className="text-muted"
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.stats.year.growth_by_country_desc_html" )
          }}
        />
        <div className="row">
          <div className="map col-md-9 col-sm-12 stacked">
            <div className="chart" />
            { currentFeatureID && (
              <button
                type="button"
                className="btn btn-default btn-bordered"
                onClick={CountryGrowth.resetVisualization}
              >
                <i className="fa fa-search-minus" />
                { I18n.t( "zoom_out" ) }
              </button>
            ) }
          </div>
          <div className="bars col-md-3 col-sm-12">
            <div className="controls">
              <select
                className="form-control stacked"
                onChange={e => {
                  this.setState( { metric: e.target.value } );
                }}
                value={metric}
              >
                <option value="percentOfTotalGrowth">{ I18n.t( "views.stats.year.percent_of_total_growth" ) }</option>
                <option value="differencePercent">{ I18n.t( "views.stats.year.percent_growth_in_year", { year } ) }</option>
                <option value="difference">{ I18n.t( "views.stats.year.growth_in_year_obs", { year } ) }</option>
                <option value="observations">{ I18n.t( "views.stats.year.obs_in_year", { year } ) }</option>
                <option value="observations_last_year">{ I18n.t( "views.stats.year.obs_in_year", { year: year - 1 } ) }</option>
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
                { I18n.t( "views.stats.year.include_usa" ) }
              </label>
              <div>
                { I18n.t( "scale_colon" ) }
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
                  { I18n.t( "linear_scale_label" ) }
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
                  { I18n.t( "log_scale_label" ) }
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
