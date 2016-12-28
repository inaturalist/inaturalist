import React, { PropTypes } from "react";
import { findDOMNode } from "react-dom";
import * as d3 from "d3";

class InteractionsForceDirectedGraph extends React.Component {
  componentDidMount( ) {
    // this.setupChart( );
  }
  componentDidUpdate( ) {
    this.setupChart( );
  }
  setupChart( ) {
    const primaryTaxon = this.props.taxon;
    console.log( "[DEBUG] setupChart" );
    const domNode = findDOMNode( this );
    const svg = d3.select( domNode );
    const width = $( domNode ).width( );
    const height = $( domNode ).height( );

    const color = d3.scaleOrdinal( d3.schemeCategory20 );

    const simulation = d3.forceSimulation( )
      .force( "link", d3.forceLink( ).id( d => d.id ) )
      // .force( "collision", d3.forceCollide( 60 ).strength( 0.4 ).iterations( 2 ) )
      .force( "charge", d3.forceManyBody( ) )
      .force( "center", d3.forceCenter( width / 2, height / 2 ) );
    const graph = {
      nodes: this.props.nodes || [],
      links: this.props.links || []
    };
    graph.links = graph.links.map( l => ( { source: l.sourceId, target: l.targetId } ) );

    // Node image patterns
    svg.append( "svg:defs" ).selectAll( "pattern" )
        .data( graph.nodes, d => d.id )
      .enter( ).append( "svg:pattern" )
        .attr( "id", d => `taxon-image-${d.id}` )
        .attr( "x", 0 )
        .attr( "y", 0 )
        // .attr( "patternUnits", "userSpaceOnUse" )
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
        .attr( "r", d => ( d.id === primaryTaxon.id ? 50 : 20 ) )
        .attr( "stroke", d => color( d.iconic_taxon_name ) )
        .attr( "stroke-width", 2 )
        .style( "fill", d => `url(#taxon-image-${d.id})` )
        .call( force.drag );
    const ticked = ( ) => {
      links.attr( "d", d => {
        const dx = d.target.x - d.source.x;
        const dy = d.target.y - d.source.y;
        const dr = Math.sqrt( dx * dx + dy * dy );
        return `M${d.source.x},${d.source.y}A${dr},${dr} 0 0,1 ${d.target.x},${d.target.y}`;
      } );
      nodes
        .attr( "cx", d => d.x )
        .attr( "cy", d => d.y );
    };
    simulation
      .nodes( graph.nodes )
      .on( "tick", ticked );
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
