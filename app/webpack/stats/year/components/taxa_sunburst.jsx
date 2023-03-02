/* eslint indent: 0 */
/* global inaturalist */
/* global iNaturalist */

import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";

// Based on https://bl.ocks.org/maybelinot/5552606564ef37b5de7e47ed2b7dc099
class TaxaSunburst extends React.Component {
  componentDidMount( ) {
    this.renderHistogram( );
  }

  renderHistogram( ) {
    if ( _.isEmpty( this.props.data ) ) { return; }
    const mountNode = $( ".chart", ReactDOM.findDOMNode( this ) ).get( 0 );
    let svg = d3.select( mountNode ).append( "svg" );
    const width = $( "svg", mountNode ).width( );
    const height = $( "svg", mountNode ).height( );
    svg
      .attr( "width", width )
      .attr( "height", height )
      .attr( "viewBox", `0 0 ${width} ${height}` )
      .attr( "preserveAspectRatio", "xMidYMid meet" );
    const radius = ( Math.min( width, height ) / 2 ) - 10;
    const x = d3.scaleLinear( ).range( [0, 2 * Math.PI] );
    const y = d3.scaleSqrt( ).range( [0, radius] );
    const color = d3.scaleOrdinal( d3.schemeCategory10 );
    const partition = d3.partition( );

    // This draws the d attribute for the visible arcs
    const arc = d3.arc( )
      .startAngle( d => Math.max( 0, Math.min( 2 * Math.PI, x( d.x0 ) ) ) )
      .endAngle( d => Math.max( 0, Math.min( 2 * Math.PI, x( d.x1 ) ) ) )
      .innerRadius( d => Math.max( 0, y( d.y0 ) ) )
      .outerRadius( d => Math.max( 0, y( d.y1 ) ) );

    // These arcs are for the text labels in the center of the visible arcs
    const centerArc = d3.arc( )
      .startAngle( d => Math.max( 0, Math.min( 2 * Math.PI, x( d.x0 ) ) ) )
      .endAngle( d => Math.max( 0, Math.min( 2 * Math.PI, x( d.x1 ) ) ) )
      .innerRadius( d => {
        const sectionWidth = Math.max( 0, y( d.y1 ) ) - Math.max( 0, y( d.y0 ) );
        return Math.max( 0, y( d.y0 ) ) + sectionWidth / 2;
      } )
      .outerRadius( d => {
        const sectionWidth = Math.max( 0, y( d.y1 ) ) - Math.max( 0, y( d.y0 ) );
        return Math.max( 0, y( d.y0 ) ) + sectionWidth / 2;
      } );
    svg = svg.attr( "width", width )
      .attr( "height", height )
      .append( "g" )
      .attr( "transform", `translate(${width / 2},${height / 2})` );

    // This strategy seems to result in a bunch of zero-angle arcs for things
    // that shouldn't be visible. This makes sure they're invisible
    const arcLabelVisibility = d => {
      const startAngle = Math.max( 0, Math.min( 2 * Math.PI, x( d.x0 ) ) );
      const endAngle = Math.max( 0, Math.min( 2 * Math.PI, x( d.x1 ) ) );
      const angle = endAngle - startAngle;
      const arcRadius = Math.max( 0, y( d.y1 ) ) - ( Math.max( 0, y( d.y1 ) )
        - Math.max( 0, y( d.y0 ) ) );
      const arcWidth = arcRadius * angle;
      const charWidth = 8;
      const labelWidth = ( d.data.preferred_common_name || d.data.name ).length * charWidth;
      return labelWidth < arcWidth ? "visible" : "hidden";
    };

    // Setup tooltips
    const tooltip = d3.select( mountNode )
        .style( "position", "relative" )
      .append( "div" )
        .attr( "class", "sunburst-tip" )
        .style( "position", "absolute" )
        .style( "z-index", "10" )
        .style( "visibility", "hidden" )
        .text( "Taxon" );

    // Setup interactivity
    const click = ( clickEvent, d ) => {
      if ( !d.children || d.children.length === 0 ) {
        return;
      }
      const tween = svg.transition( )
        .duration( 750 )
        .tween( "scale", ( ) => {
          const xd = d3.interpolate( x.domain( ), [d.x0, d.x1] );
          const yd = d3.interpolate( y.domain( ), [d.y0, 1] );
          const yr = d3.interpolate( y.range( ), [d.y0 ? 20 : 0, radius] );
          return t => {
            x.domain( xd( t ) );
            y.domain( yd( t ) ).range( yr( t ) );
          };
        } );
      tween.selectAll( "path.sunburst-arc" )
        .attrTween( "d", dd => ( ) => arc( dd ) )
        .styleTween( "visibility", dd => ( ) => {
          const startAngle = Math.max( 0, Math.min( 2 * Math.PI, x( dd.x0 ) ) );
          const endAngle = Math.max( 0, Math.min( 2 * Math.PI, x( dd.x1 ) ) );
          const angle = endAngle - startAngle;
          return angle < 0.000000001 ? "hidden" : "visible";
        } );
      tween.selectAll( "path.center-arc" )
        .attrTween( "d", dd => ( ) => centerArc( dd ) );
      tween.selectAll( "text" )
        .styleTween( "visibility", dd => ( ) => arcLabelVisibility( dd ) );
    };

    // Set up the hierarchy
    const { data, rootTaxonID } = this.props;
    const taxaCounts = _.keyBy( data, r => r.taxon.id );
    const children = { };
    _.each( data, result => {
      if ( !result.isLeaf ) { return; }
      if ( result.taxon.ancestor_ids[0] !== rootTaxonID ) { return; }
      let lastAncestorID;
      _.each( result.taxon.ancestor_ids, ancestorID => {
        if ( ancestorID !== rootTaxonID && ancestorID !== lastAncestorID ) {
          children[lastAncestorID] = children[lastAncestorID] || { };
          children[lastAncestorID][ancestorID] = true;
        }
        lastAncestorID = ancestorID;
      } );
    } );
    const recurse = taxonID => {
      const thisData = {
        id: taxonID,
        name: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.name : I18n.t( "unknown" ),
        rank: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.rank : null,
        preferred_common_name: taxaCounts[taxonID]
          ? taxaCounts[taxonID].taxon.preferred_common_name
          : null,
        iconicTaxonID: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.iconic_taxon_id : null,
        count: taxaCounts[taxonID] ? taxaCounts[taxonID].count : 0
      };
      if ( children[taxonID] ) {
        thisData.children = _.map( children[taxonID], ( v, childID ) => (
          recurse( childID )
        ) );
      } else {
        thisData.size = taxaCounts[taxonID] ? taxaCounts[taxonID].count : 0;
      }
      return thisData;
    };
    const rootData = recurse( rootTaxonID );
    const theRoot = d3.hierarchy( rootData );
    theRoot.sum( d => d.size );

    const colorForDatum = d => {
      if ( d.data.iconicTaxonID && inaturalist.ICONIC_TAXA[d.data.iconicTaxonID] ) {
        const iconicTaxonColor = iNaturalist.Map
          .ICONIC_TAXON_COLORS[inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name];
        let c = d3.color( iconicTaxonColor );
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Mollusca" ) {
          c = c.brighter( );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Arachnida" ) {
          c = c.brighter( 2 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Actinopterygii" ) {
          c = c.darker( 1 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Amphibia" ) {
          c = c.darker( 0.5 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Reptilia" ) {
          c = c.brighter( 0.75 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Aves" ) {
          c = c.brighter( 0.5 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Mammalia" ) {
          c = c.brighter( 1 );
        }
        // if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Animalia" ) {
        //   return c.brighter( 1.5 );
        // }
        c = c.brighter( _.random( 0, 0.25 ) ).darker( _.random( 0, 0.25 ) );
        c.opacity = _.random( 0.8, 1 );
        return c;
      }
      return color( ( d.children ? d : d.parent ).data.name );
    };

    // Draw the arcs
    const { labelForDatum } = this.props;
    svg.selectAll( "path" )
        .data( partition( theRoot ).descendants( ) )
      .enter( ).append( "path" )
        .attr( "d", arc )
        .style( "fill", colorForDatum )
        .classed( "clickable", d => ( d.children && d.children.length > 0 ) )
        .classed( "sunburst-arc", true )
        .on( "click", click )
        .on( "mouseover", ( mouseoverEvent, d ) => {
          if ( labelForDatum ) {
            tooltip.html( labelForDatum( d ) );
          } else {
            tooltip.html( d.data.name );
          }
          tooltip.style( "background-color", d3.color( colorForDatum( d ) ).darker( 2 ) );
          return tooltip.style( "visibility", "visible" );
        } )
        .on( "mousemove", mousemoveEvent => {
          const pos = d3.pointer( mousemoveEvent, mountNode );
          return tooltip.style( "top", `${pos[1] - 10}px` )
            .style( "left", `${pos[0] + 10}px` );
        } )
        .on( "mouseout", ( ) => tooltip.style( "visibility", "hidden" ) );

    const labels = svg.append( "g" );
    labels.selectAll( "path" )
        .data( partition( theRoot ).descendants( ) )
      .enter( ).append( "path" )
        .attr( "d", centerArc )
        .attr( "class", "center-arc" )
        // .style( "stroke", "red" )
        .attr( "id", d => `taxon-path-${d.data.id}` );

    // Draw the labels
    // https://www.visualcinnamon.com/2015/09/placing-text-on-arcs.html
    labels.selectAll( "text" )
        .data( partition( theRoot ).descendants( ) )
      .enter( )
        .append( "text" )
          .attr( "x", 20 )
          .attr( "dy", 2 )
          .style( "letter-spacing", "0.2em" )
          .style( "visibility", arcLabelVisibility )
        .append( "textPath" )
          .attr( "xlink:href", d => `#taxon-path-${d.data.id}` )
          .style( "text-anchor", "left" )
          .attr( "class", d => d.data.rank )
          .classed( "sciname", d => !d.data.preferred_common_name )
          .text( d => d.data.preferred_common_name || d.data.name );

    d3.select( self.frameElement ).style( "height", `${height}px` );
  }

  render( ) {
    return (
      <div className="TaxaSunburst">
        <h3>
          <a name="species-observed" href="#species-observed">
            <span>{ I18n.t( "views.welcome.index.species_observed" ) }</span>
          </a>
        </h3>
        <p
          className="text-muted"
          dangerouslySetInnerHTML={{ __html: I18n.t( "views.stats.year.sunburst_desc_html" ) }}
        />
        <div className="chart" />
      </div>
    );
  }
}

TaxaSunburst.propTypes = {
  data: PropTypes.array,
  rootTaxonID: PropTypes.number.isRequired,
  labelForDatum: PropTypes.func
};

export default TaxaSunburst;
