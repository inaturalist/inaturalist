import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import * as d3 from "d3";
/* global inaturalist */
/* global iNaturalist */

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
    const radius = ( Math.min( width, height ) / 2 ) - 10;
    const formatNumber = d3.format( ",d" );
    const x = d3.scaleLinear( ).range( [0, 2 * Math.PI] );
    const y = d3.scaleSqrt( ).range( [0, radius] );
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
    const taxaCounts = _.keyBy( this.props.data, r => r.taxon.id );
    const children = { };
    _.each( this.props.data, result => {
      if ( !result.isLeaf ) { return; }
      if ( result.taxon.ancestor_ids[0] !== 48460 ) { return; }
      let lastAncestorID;
      _.each( result.taxon.ancestor_ids, ancestorID => {
        if ( ancestorID !== 48460 && ancestorID !== lastAncestorID ) {
          children[lastAncestorID] = children[lastAncestorID] || { };
          children[lastAncestorID][ancestorID] = true;
        }
        lastAncestorID = ancestorID;
      } );
    } );

    const recurse = ( taxonID ) => {
      const thisData = {
        name: taxaCounts[taxonID] ? taxaCounts[taxonID].taxon.name : "Unknown",
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


    const click = d => {
      svg.transition( )
          .duration( 750 )
          .tween( "scale", ( ) => {
            const xd = d3.interpolate( x.domain( ), [d.x0, d.x1] );
            const yd = d3.interpolate( y.domain( ), [d.y0, 1] );
            const yr = d3.interpolate( y.range( ), [d.y0 ? 20 : 0, radius] );
            return t => {
              x.domain( xd( t ) );
              y.domain( yd( t ) ).range( yr( t ) );
            };
          } )
        .selectAll( "path" )
          .attrTween( "d", dd => ( ) => arc( dd ) );
    };

    const rootData = recurse( 48460 );
    const theRoot = d3.hierarchy( rootData );
    theRoot.sum( d => d.size );
    svg.selectAll( "path" )
        .data( partition( theRoot ).descendants( ) )
      .enter( ).append( "path" )
        .attr( "d", arc )
        .style( "fill", d => {
          if ( d.data.iconicTaxonID && inaturalist.ICONIC_TAXA[d.data.iconicTaxonID] ) {
            const specialColor = iNaturalist.Map.
              ICONIC_TAXON_COLORS[inaturalist.ICONIC_TAXA[d.data.iconicTaxonID].name];
            const c = d3.color( specialColor ).
              brighter( _.random( 0, 0.5 ) ).darker( _.random( 0, 0.5 ) );
            c.opacity = _.random( 0.8, 1 );
            return c;
          }
          return color( ( d.children ? d : d.parent ).data.name );
        } )
        .on( "click", click )
      .append( "title" )
        .text( d => `${d.data.name}\n${formatNumber( d.value )}` );

    d3.select( self.frameElement ).style( "height", `${height}px` );
  }

  render( ) {
    return (
      <div className="TaxaSunburst">
        <h3><span>Species Observed</span></h3>
        <div className="chart"></div>
      </div>
    );
  }
}

TaxaSunburst.propTypes = {
  data: PropTypes.array
};

export default TaxaSunburst;
