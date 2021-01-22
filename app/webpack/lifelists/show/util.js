function nodeObsCount( lifelist, search ) {
  return function ( node ) {
    if ( lifelist.speciesPlaceFilter
      && search
      && search.searchResponse
      && search.loaded
    ) {
      return search.searchResponse.results[node.id] || 0;
    }
    return node.descendant_obs_count;
  };
}

function filteredNodes( lifelist, search ) {
  const { detailsTaxon } = lifelist;
  let nodeShouldDisplay;
  const nodeIsDescendant = ( !detailsTaxon || detailsTaxon === "root" )
    ? ( ) => true
    : node => node.left >= detailsTaxon.left && node.right <= detailsTaxon.right;
  const obsCount = nodeObsCount( lifelist, search );
  if ( lifelist.speciesViewRankFilter === "all" ) {
    if ( !detailsTaxon || detailsTaxon === "root" ) {
      nodeShouldDisplay = nodeIsDescendant;
    } else {
      nodeShouldDisplay = node => (
        ( detailsTaxon.left === detailsTaxon.right - 1 && node.id === detailsTaxon.id )
        || ( node.left > detailsTaxon.left && node.right < detailsTaxon.right )
      );
    }
  } else if ( lifelist.speciesViewRankFilter === "children" ) {
    nodeShouldDisplay = node => node.parent_id === ( !detailsTaxon || detailsTaxon === "root" ? 0 : detailsTaxon.id );
  } else if ( lifelist.speciesViewRankFilter === "major" ) {
    nodeShouldDisplay = node => node.rank_level % 10 === 0;
  } else if ( lifelist.speciesViewRankFilter === "kingdoms" ) {
    nodeShouldDisplay = node => node.rank_level === 70;
  } else if ( lifelist.speciesViewRankFilter === "phyla" ) {
    nodeShouldDisplay = node => node.rank_level === 60;
  } else if ( lifelist.speciesViewRankFilter === "classes" ) {
    nodeShouldDisplay = node => node.rank_level === 50;
  } else if ( lifelist.speciesViewRankFilter === "orders" ) {
    nodeShouldDisplay = node => node.rank_level === 40;
  } else if ( lifelist.speciesViewRankFilter === "families" ) {
    nodeShouldDisplay = node => node.rank_level === 30;
  } else if ( lifelist.speciesViewRankFilter === "genera" ) {
    nodeShouldDisplay = node => node.rank_level === 20;
  } else if ( lifelist.speciesViewRankFilter === "species" ) {
    nodeShouldDisplay = node => node.rank_level === 10;
  } else if ( lifelist.speciesViewRankFilter === "leaves" ) {
    nodeShouldDisplay = node => (
      node.rank_level === 10 || (
        node.left === node.right - 1 && node.rank_level > 10
      ) || (
        detailsTaxon && detailsTaxon.rank_level < 10 && detailsTaxon.id === node.id
      )
    );
  }
  if ( !nodeShouldDisplay ) return null;

  return _.filter( lifelist.taxa,
    t => nodeIsDescendant( t ) && nodeShouldDisplay( t ) && obsCount( t ) );
}

function rankLabel( { rank: filter, withLeaves = true } = {} ) {
  switch ( filter ) {
    case "kingdoms":
    case "phyla":
    case "classes":
    case "orders":
    case "families":
    case "genera":
    case "species":
      return I18n.t( `ranks.x_${filter}`, { count: 2 } );
    case "leaves":
      return ( withLeaves ? I18n.t( "ranks.leaves" ) : I18n.t( "ranks.x_species", { count: 2 } ) );
    default:
      return I18n.t( "views.lifelists.dropdowns.children" );
  }
}

export {
  rankLabel,
  filteredNodes,
  nodeObsCount
};
