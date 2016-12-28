import _ from "lodash";
import iNaturalistJS from "inaturalistjs";
import { stringify } from "querystring";

const SET_INTERACTIONS = "taxa-show/interactions/SET_INTERACTIONS";

export default function reducer( state = { }, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SET_INTERACTIONS: {
      // d3 goes into fits if you feed it links that reference nodes that don't
      // exist, so we need to make sure every link references nodes we know
      // about
      const nodeHash = _.groupBy( action.nodes, n => n.id );
      const filteredLinks = _.filter( action.links, l => ( nodeHash[l.sourceId] && nodeHash[l.targetId] ) );
      newState.nodes = action.nodes;
      newState.links = filteredLinks;
      break;
    }
    default:
      // all good
  }
  return newState;
}

export function setInteractions( nodes, links ) {
  return {
    type: SET_INTERACTIONS,
    nodes,
    links
  };
}

export function fetchInatInteractions( taxon ) {
  return ( dispatch, getState ) => {
    console.log( "[DEBUG] fetchInatInteractions" );
    const t = taxon || getState( ).taxon.taxon;
    const eatingParams = {
      taxon_id: t.id,
      "field:eating": "",
      quality: "research"
    };
    const eatenByParams = {
      "field:eating": t.id,
      quality: "research"
    };
    iNaturalistJS.observations.search( eatingParams ).then(
      eatingResponse => {
        // console.log( "[DEBUG] eatingResponse.results.length: ", eatingResponse.results.length );
        const links = eatingResponse.results.map( observation => {
          const targetId = parseInt( _.find( observation.ofvs, ofv => ofv.name === "Eating" ).value, 0 );
          const urlParams = Object.assign( {}, eatingParams, {
            "field:eating": targetId
          } );
          return {
            sourceId: parseInt( t.id, 0 ),
            targetId,
            type: "eats",
            url: `/observations?${stringify( urlParams )}`
          };
        } );
        iNaturalistJS.observations.search( eatenByParams ).then(
          eatenByResponse => {
            // console.log( "[DEBUG] eatenByResponse.results.length: ", eatenByResponse.results.length );
            eatenByResponse.results.forEach( observation => {
              const urlParams = Object.assign( { }, eatenByParams, {
                taxon_id: observation.taxon.id
              } );
              links.push( {
                sourceId: parseInt( observation.taxon.id, 0 ),
                targetId: parseInt( t.id, 0 ),
                type: "eats",
                url: `/observations?${stringify( urlParams )}`
              } );
            } );
            const filteredLinks = _.filter( links, l => ( l.sourceId && l.targetId ) );
            // console.log( "[DEBUG] links: ", links );
            const taxonIds = _.uniq(
              _.flatten( filteredLinks.map( link => [link.sourceId, link.targetId] ) )
            );
            console.log( "[DEBUG] taxonIds: ", taxonIds );
            iNaturalistJS.taxa.fetch( taxonIds ).then(
              taxaResponse => {
                dispatch( setInteractions( taxaResponse.results, filteredLinks ) );
              }
            );
          }
        );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchGlobiInteractions( taxon ) {
  return ( dispatch, getState ) => {
    const t = taxon || getState( ).taxon.taxon;
    const params = {
      sourceTaxon: t.name,
      type: "json.v2",
      accordingTo: "iNaturalist"
    };
    const url = `http://api.globalbioticinteractions.org/interaction?${stringify( params )}`;
    // console.log( "[DEBUG] globi url: ", url );
    fetch( url ).then(
      response => {
        response.json( ).then( interactions => {
          const inatTaxonIds = _.uniq( interactions.map( interaction =>
            interaction.target_taxon_external_id.split( ":" )[1] ) );
          inatTaxonIds.push( t.id );
          // console.log( "[DEBUG] inatTaxonIds: ", inatTaxonIds );
          iNaturalistJS.taxa.fetch( inatTaxonIds ).then( taxaResponse => {
            const nodes = taxaResponse.results;
            const links = interactions.map( interaction => {
              const targetId = parseInt( interaction.target_taxon_external_id.split( ":" )[1], 0 );
              const urlParams = Object.assign( { }, params, {
                targetTaxon: interaction.target.name
              } );
              return {
                sourceId: parseInt( t.id, 0 ),
                targetId,
                type: interaction.interaction_type,
                url: `http://api.globalbioticinteractions.org/interaction?${stringify( urlParams )}`
              };
            } );
            dispatch( setInteractions( nodes, links ) );
          } );
        } );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}
