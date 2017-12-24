import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";
/* global inaturalist */
/* global iNaturalist */

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
    const y = d3.scaleLinear( ).range( [0, radius] );
    const color = d3.scaleOrdinal( d3.schemeCategory20 );
    const partition = d3.partition( );
    const arc = d3.arc( )
        .startAngle( d => Math.max( 0, Math.min( 2 * Math.PI, x( d.x0 ) ) ) )
        .endAngle( d => Math.max( 0, Math.min( 2 * Math.PI, x( d.x1 ) ) ) )
        .innerRadius( d => Math.max( 0, y( d.y0 ) ) )
        .outerRadius( d => Math.max( 0, y( d.y1 ) ) );
    svg = svg.attr( "width", width )
       .attr( "height", height )
       .append( "g" )
       .attr( "transform", `translate(${width / 2},${height / 2})` );

    const arcLabelVisibility = d => {
      const startAngle = Math.max( 0, Math.min( 2 * Math.PI, x( d.x0 ) ) );
      const endAngle = Math.max( 0, Math.min( 2 * Math.PI, x( d.x1 ) ) );
      const angle = endAngle - startAngle;
      const arcRadius = Math.max( 0, y( d.y1 ) ) - ( Math.max( 0, y( d.y1 ) ) - Math.max( 0, y( d.y0 ) ) );
      const arcWidth = arcRadius * angle;
      const charWidth = 10;
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
    const click = d => {
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
      tween.selectAll( "path" )
        .attrTween( "d", dd => ( ) => arc( dd ) );
      tween.selectAll( "text" )
        .styleTween( "visibility", dd => ( ) => arcLabelVisibility( dd ) );
    };

    // Set up the hierarchy
    const taxaCounts = _.keyBy( this.props.data, r => r.taxon.id );
    const children = { };
    _.each( this.props.data, result => {
      if ( !result.isLeaf ) { return; }
      if ( result.taxon.ancestor_ids[0] !== this.props.rootTaxonID ) { return; }
      let lastAncestorID;
      _.each( result.taxon.ancestor_ids, ancestorID => {
        if ( ancestorID !== this.props.rootTaxonID && ancestorID !== lastAncestorID ) {
          children[lastAncestorID] = children[lastAncestorID] || { };
          children[lastAncestorID][ancestorID] = true;
        }
        lastAncestorID = ancestorID;
      } );
    } );
    const recurse = ( taxonID ) => {
      const thisData = {
        id: taxonID,
        name: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.name : I18n.t( "unknown" ),
        rank: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.rank : null,
        preferred_common_name: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.preferred_common_name : null,
        iconicTaxonID: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.iconic_taxon_id : null
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
    const rootData = recurse( this.props.rootTaxonID );
    const theRoot = d3.hierarchy( rootData );
    theRoot.sum( d => d.size );

    const colorForDatum = d => {
      if ( d.data.iconicTaxonID && inaturalist.ICONIC_TAXA[d.data.iconicTaxonID] ) {
        const iconicTaxonColor = iNaturalist.Map.
          ICONIC_TAXON_COLORS[inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name];
        const c = d3.color( iconicTaxonColor );
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Mollusca" ) {
          return c.brighter( );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Arachnida" ) {
          return c.brighter( 2 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Amphibia" ) {
          return c.brighter( 0.5 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Reptilia" ) {
          return c.brighter( 0.75 );
        }
        if ( inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name === "Aves" ) {
          return c.brighter( 1 );
        }
        return c;
      }
      return color( ( d.children ? d : d.parent ).data.name );
    };

    // Draw the arcs
    svg.selectAll( "path" )
        .data( partition( theRoot ).descendants( ) )
      .enter( ).append( "path" )
        .attr( "d", arc )
        .attr( "id", d => `taxon-path-${d.data.id}` )
        .style( "fill", colorForDatum )
        .classed( "clickable", d => ( d.children && d.children.length > 0 ) )
        .classed( "sunburst-arc", true )
        .on( "click", click )
        .on( "mouseover", d => {
          if ( this.props.labelForDatum ) {
            tooltip.html( this.props.labelForDatum( d ) );
          } else {
            tooltip.html( d.data.name );
          }
          tooltip.style( "background-color", d3.color( colorForDatum( d ) ).darker( 2 ) );
          return tooltip.style( "visibility", "visible" );
        } )
        .on( "mousemove", ( ) => tooltip.style(
          "top", `${event.offsetY - 10}px` ).style( "left", `${event.offsetX + 10}px`
        ) )
        .on( "mouseout", ( ) => tooltip.style( "visibility", "hidden" ) );

    // Draw the labels
    // https://www.visualcinnamon.com/2015/09/placing-text-on-arcs.html
    svg.selectAll( "text" )
        .data( partition( theRoot ).descendants( ) )
      .enter( )
        .append( "text" )
          .attr( "x", 20 )
          .attr( "dy", d => (
            ( Math.max( 0, y( d.y1 ) ) - Math.max( 0, y( d.y0 ) ) ) / 3 * 2
          ) )
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
        <h3><span>{ I18n.t( "views.welcome.index.species_observed" ) }</span></h3>
        <p
          className="text-muted"
          dangerouslySetInnerHTML={ { __html: I18n.t( "views.stats.year.sunburst_desc_html" ) } }
        />
        <div className="chart"></div>
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
