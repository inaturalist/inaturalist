import React, { PropTypes } from "react";
import { findDOMNode } from "react-dom";
import * as d3 from "d3";
import d3tip from "d3-tip";

class InteractionsForceDirectedGraph extends React.Component {
  componentDidUpdate( ) {
    this.setupChart( );
  }
  setupChart( ) {
    // d3tip( d3 );
    const domNode = findDOMNode( this );
    const svg = d3.select( domNode );
    const width = $( domNode ).width( );
    const height = $( domNode ).height( );
    const radius = 20;
    const color = d3.scaleOrdinal( d3.schemeCategory20 );
    const simulation = d3.forceSimulation( )
      .force( "link", d3.forceLink( ).id( d => d.id ) )
      .force( "collision", d3.forceCollide( 60 ).strength( 0.4 ).iterations( 2 ) )
      .force( "charge", d3.forceManyBody( ) )
      .force( "center", d3.forceCenter( width / 2, height / 2 ) );
    const graph = {
      nodes: this.props.nodes || [],
      links: this.props.links || []
    };
    graph.links = graph.links.map( l => ( { source: l.sourceId, target: l.targetId } ) );

    const tip = d3tip()
      .attr( "class", "d3-tip" )
      .direction( "s" )
      .offset( [10, 0] )
      .html( d =>
        `<div class="tooltip bottom"><div class="tooltip-arrow"></div><div class="tooltip-inner">${d.name}</div></div>`
      );
    svg.call( tip );

    // Node image patterns
    svg.append( "svg:defs" ).selectAll( "pattern" )
        .data( graph.nodes, d => d.id )
      .enter( ).append( "svg:pattern" )
        .attr( "id", d => `taxon-image-${d.id}` )
        .attr( "x", 0 )
        .attr( "y", 0 )
        .attr( "patternContentUnits", "objectBoundingBox" )
        .attr( "width", 1 )
        .attr( "height", 1 )
      .append( "svg:image" )
        .attr( "x", 0 )
        .attr( "y", 0 )
        .attr( "width", 1 )
        .attr( "height", 1 )
        .attr( "xlink:xlink:href", d => {
          if ( d.defaultPhoto ) {
            return d.defaultPhoto.photoUrl( );
          }
          return "http://www.inaturalist.org/assets/iconic_taxa/unknown-cccccc-20px.png";
        } )
        .attr( "preserveAspectRatio", "xMinYMin slice" );
    // Edge midpoint marker pattern
    svg.append( "svg:defs" ).selectAll( "marker" )
        .data( ["end"] )      // Different link/path types can be defined here
      .enter( ).append( "svg:marker" )    // This section adds in the arrows
        .attr( "id", String )
        .attr( "viewBox", "0 -5 10 10" )
        .attr( "refX", 15 )
        .attr( "refY", -1.5 )
        .attr( "markerWidth", 6 )
        .attr( "markerHeight", 6 )
        .attr( "orient", "auto" )
      .append( "svg:path" )
        .attr( "d", "M0,-5L10,0L0,5" );
    // Edges
    const links = svg.append( "g" )
        .attr( "class", "links" )
      .selectAll( "path" )
      .data( graph.links )
      .enter( ).append( "path" )
        .attr( "key", d => `link-${d.sourceId}-${d.targetId}` )
        .attr( "stroke", "#ccc" )
        .attr( "stroke-width", 1 )
        .attr( "fill", "transparent" )
        .attr( "marker-mid", "url(#end)" );
    // Nodes
    const nodes = svg.append( "g" )
        .attr( "class", "nodes" )
      .selectAll( "circle" )
      .data( graph.nodes )
      .enter( ).append( "circle" )
        .attr( "key", d => `node-${d.id}` )
        .attr( "r", radius )
        .attr( "stroke", d => color( d.iconic_taxon_name ) )
        .attr( "stroke-width", 2 )
        .style( "fill", d => `url(#taxon-image-${d.id})` )
        .on( "mouseover", tip.show )
        .on( "mouseout", tip.hide )
        .call( d3.drag( )
          .on( "start", d => {
            if ( !d3.event.active ) simulation.alphaTarget( 0.3 ).restart( );
            d.fx = d.x;
            d.fy = d.y;
          } )
          .on( "drag", d => {
            d.fx = d3.event.x;
            d.fy = d3.event.y;
          } )
          .on( "end", d => {
            if ( !d3.event.active ) simulation.alphaTarget( 0 );
            d.fx = null;
            d.fy = null;
          } ) );
    const ticked = ( ) => {
      nodes
        .attr( "cx", d => Math.max( radius, Math.min( width - radius, d.x ) ) )
        .attr( "cy", d => Math.max( radius, Math.min( height - radius, d.y ) ) );
      links.attr( "d", d => {
        const targetX = Math.max( radius, Math.min( width - radius, d.target.x ) );
        const targetY = Math.max( radius, Math.min( height - radius, d.target.y ) );
        const sourceX = Math.max( radius, Math.min( width - radius, d.source.x ) );
        const sourceY = Math.max( radius, Math.min( height - radius, d.source.y ) );
        const dx = targetX - sourceX;
        const dy = targetY - sourceY;
        const dr = Math.sqrt( dx * dx + dy * dy );
        return `M${sourceX},${sourceY}A${dr},${dr} 0 0,1 ${targetX},${targetY}`;
      } );
    };
    simulation
      .nodes( graph.nodes )
      .on( "tick", ticked );
    console.log( "[DEBUG] feeding simulation its links" );
    simulation.force( "link" )
      .links( graph.links );
  }
  render( ) {
    return (
      <svg
        className="InteractionsForceDirectedGraph"
        style={{ width: "100%", height: 500 }}
      >
      </svg>
    );
  }
}

InteractionsForceDirectedGraph.propTypes = {
  nodes: PropTypes.array,
  links: PropTypes.array,
  taxon: PropTypes.object
};

export default InteractionsForceDirectedGraph;
