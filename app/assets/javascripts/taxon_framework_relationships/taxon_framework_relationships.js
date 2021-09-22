/* global d3 */
/* eslint no-unused-vars: 0 */
function tfrD3Vis( data, tfrId ) {
  var stratify = d3.stratify()
    .id( function ( d ) { return ( d.name == null ? null : ( d.name + "_" + d.rank ) ); } )
    .parentId( function ( d ) { return ( d.parent_name == null ? null : ( d.parent_name + "_" + d.parent_rank ) ); } );

  function formatName( d ) {
    if ( d.id == null ) {
      return null;
    }
    var rankSplit = d.id.split( "_" );
    var rank = rankSplit[1];
    var splitString = rankSplit[0].split( " " );
    var firstWord = splitString.shift();
    if ( d.data.rank === "species" ) {
      splitString.unshift( firstWord[0] + "." );
      splitString = splitString.join( " " );
    } else if ( d.data.rank === "subspecies" || d.data.rank === "variety" ) {
      var secondWord = splitString.shift();
      splitString.unshift( secondWord[0] + "." );
      splitString.unshift( firstWord[0] + "." );
      splitString = splitString.join( " " );
    } else {
      splitString = rankSplit[0];
    }
    return splitString;
  }

  function truncate( d, cutoff ) {
    if ( d == null ) {
      return null;
    }
    var returnValue = d;
    if ( d.length > cutoff ) {
      returnValue = d.substring( 0, ( cutoff - 3 ) ) + "...";
    }
    return returnValue;
  }

  data.internal_taxa.sort( function ( a, b ) {
    return ( a.name > b.name ) ? 1 : -1;
  } );
  var rootInternal = stratify( data.internal_taxa );
  var sortOrder = rootInternal.descendants().map( function ( d ) { return d.data; } );

  var dataExternalTaxa = [];
  var dataInternalTaxaNames = sortOrder.map( function ( j ) { return j.name; } );
  var dataExternalTaxaNames = data.external_taxa.map( function ( j ) { return j.name; } );

  data.external_taxa.forEach( function ( et ) {
    var newEt = et;
    var match = dataInternalTaxaNames.indexOf( et.name );
    if ( match ) {
      newEt.ind = match;
    } else {
      newEt.ind = dataExternalTaxaNames.indexOf( et.name );
    }
    dataExternalTaxa.push( et );
  } );

  dataExternalTaxa.sort( function ( a, b ) {
    var a1 = a.ind;
    var b1 = b.ind;
    if ( a1 === b1 ) return 0;
    return a1 > b1 ? 1 : -1;
  } );

  var rootExternal = stratify( dataExternalTaxa ).sort( function ( a, b ) {
    var a1 = a.data.ind;
    var b1 = b.data.ind;
    if ( a1 === b1 ) return 0;
    return a1 > b1 ? 1 : -1;
  } );
  var numRows = Math.max( rootExternal.descendants().length, rootInternal.descendants().length );

  // set up the svg
  var margin = {
    top: 1, right: 1, bottom: 1, left: 1
  };
  var width = 800 - margin.left - margin.right;
  var offset1 = 100;
  var offset2 = ( width / 2 + 75 );
  var height = Math.max( ( numRows * 12 ), 200 ) - margin.top - margin.bottom;

  var svg = d3.select( "div.tfr_" + tfrId ).append( "svg" )
    .attr( "viewBox", "0 0 " + ( width + margin.left + margin.right ) + " " + ( height + margin.top + margin.bottom ) )
    .attr( "preserveAspectRatio", "xMinYMin meet" );

  var tree = d3.cluster()
    .size( [height, width / 4.5] );

  // get the trees
  tree( rootExternal );
  tree( rootInternal );

  // groups for the two background trees
  var g = svg.append( "g" ).attr( "transform", "translate(" + offset1 + ",0)" );
  var g2 = svg.append( "g" ).attr( "transform", "translate(" + offset2 + ")" );

  g.selectAll( ".link" )
    .data( rootInternal.descendants().slice( 1 ) )
    .enter().append( "path" )
    .attr( "class", "link" )
    .attr( "d", function ( d ) {
      return "M" + d.y + "," + d.x + "C" + ( d.parent.y + 50 ) + "," + d.x + " " + ( d.parent.y + 50 ) + "," + d.parent.x + " " + d.parent.y + "," + d.parent.x;
    } );

  var trianglePoints = ( width / 2 - 35 ) + " " + ( height / 2 + 15 ) + ", " + ( width / 2 - 15 ) + " " + ( height / 2 + 10 ) + ", " + ( width / 2 - 35 ) + " " + ( height / 2 + 5 );

  svg.append( "polyline" )
    .attr( "points", trianglePoints );

  g2.selectAll( ".link" )
    .data( rootExternal.descendants().slice( 1 ) )
    .enter().append( "path" )
    .attr( "class", "link" )
    .attr( "d", function ( d ) {
      return "M" + d.y + "," + d.x + "C" + ( d.parent.y + 50 ) + "," + d.x + " " + ( d.parent.y + 50 ) + "," + d.parent.x + " " + d.parent.y + "," + d.parent.x;
    } );

  var node = g.selectAll( ".node" )
    .data( rootInternal.descendants() )
    .enter().append( "g" )
    .attr( "class", function ( d ) { return "node" + ( d.children ? " node--internal" : " node--leaf" ); } )
    .attr( "transform", function ( d ) { return "translate(" + d.y + "," + d.x + ")"; } );

  node.append( "circle" )
    .style( "fill", function ( d ) {
      return d.parent == null ? "gray" : "#76AC1E";
    } )
    .attr( "r", 4 )
    .on( "mouseover", function ( d ) {
      if ( d.data.url != null ) {
        d3.select( this ).style( "cursor", "pointer" );
      }
    } )
    .on( "mouseout", function () {
      d3.select( this ).style( "cursor", "default" );
    } )
    .on( "click", function ( d ) {
      if ( d.data.url != null ) {
        var url = "/taxa/" + d.data.url;
        window.location = url;
      }
    } );

  var node2 = g2.selectAll( ".node" )
    .data( rootExternal.descendants() )
    .enter().append( "g" )
    .attr( "class", function ( d ) { return "node" + ( d.children ? " node--internal" : " node--leaf" ); } )
    .attr( "transform", function ( d ) { return "translate(" + d.y + "," + d.x + ")"; } );

  node2.append( "circle" )
    .style( "fill", function ( d ) {
      return d.parent == null ? "gray" : "#76AC1E";
    } )
    .attr( "r", 4 )
    .on( "mouseover", function ( d ) {
      if ( d.data.url != null ) {
        d3.select( this ).style( "cursor", "pointer" );
      }
    } )
    .on( "mouseout", function () {
      d3.select( this ).style( "cursor", "default" );
    } )
    .on( "click", function ( d ) {
      if ( d.data.url != null ) {
        window.location = d.data.url;
      }
    } );

  // group for the labels
  var g1 = svg.append( "g" ).attr( "transform", "translate(" + offset1 + ",0)" );
  var g21 = svg.append( "g" ).attr( "transform", "translate(" + offset2 + ")" );

  var lnode = g1.selectAll( ".node" )
    .data( rootInternal.descendants() )
    .enter().append( "g" )
    .attr( "class", function ( d ) { return "node" + ( d.children ? " node--internal" : " node--leaf" ); } )
    .attr( "transform", function ( d ) { return "translate(" + d.y + "," + d.x + ")"; } );

  lnode.append( "text" )
    .attr( "dy", 3 )
    .attr( "x", function ( d ) { return d.children ? -8 : 8; } )
    .style( "text-anchor", function ( d ) { return d.children ? "end" : "start"; } )
    .text( function ( d ) { return truncate( formatName( d ), 17 ); } );

  var lnode2 = g21.selectAll( ".node" )
    .data( rootExternal.descendants() )
    .enter().append( "g" )
    .attr( "class", function ( d ) { return "node" + ( d.children ? " node--internal" : " node--leaf" ); } )
    .attr( "transform", function ( d ) { return "translate(" + d.y + "," + d.x + ")"; } );

  lnode2.append( "text" )
    .attr( "dy", 3 )
    .attr( "x", function ( d ) { return d.children ? -8 : 8; } )
    .style( "text-anchor", function ( d ) { return d.children ? "end" : "start"; } )
    .text( function ( d ) { return truncate( formatName( d ), 17 ); } );
}
