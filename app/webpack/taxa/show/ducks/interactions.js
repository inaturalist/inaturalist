import _ from "lodash";
import iNaturalistJS from "inaturalistjs";
import querystring from "querystring";

const SET_INTERACTIONS = "taxa-show/interactions/SET_INTERACTIONS";

export default function reducer( state = { nodes: [], links: [] }, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SET_INTERACTIONS:
      newState.nodes = action.nodes;
      newState.links = action.links;
      break;
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
  return dispatch => {
    const eatingParams = {
      taxon_id: taxon.id,
      "field:eating": "",
      quality: "research"
    };
    const eatenByParams = {
      "field:eating": taxon.id,
      quality: "research"
    };
    iNaturalistJS.observations.search( eatingParams ).then(
      eatingResponse => {
        console.log( "[DEBUG] eatingResponse.results.length: ", eatingResponse.results.length );
        const links = eatingResponse.results.map( observation => ( {
          sourceId: taxon.id,
          targetId: _.find( observation.ofvs, ofv => ofv.name === "Eating" ).value
        } ) );
        iNaturalistJS.observations.search( eatenByParams ).then(
          eatenByResponse => {
            console.log( "[DEBUG] eatenByResponse.results.length: ", eatenByResponse.results.length );
            eatenByResponse.results.forEach( observation => {
              links.push( {
                sourceId: observation.taxon.id,
                targetId: taxon.id
              } );
            } );
            console.log( "[DEBUG] links: ", links );
            const taxonIds = _.uniq(
              _.flatten( links.map( link => [link.sourceId, link.targetId] ) )
            );
            console.log( "[DEBUG] taxonIds: ", taxonIds );
            iNaturalistJS.taxa.fetch( taxonIds ).then(
              taxaResponse => {
                dispatch( setInteractions( taxaResponse.results, links ) );
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
  return ( dispatch ) => {
    const params = {
      sourceTaxon: taxon.name,
      type: "json.v2",
      accordingTo: "iNaturalist"
    };
    const url = `http://api.globalbioticinteractions.org/interaction?${querystring.stringify( params )}`;
    console.log( "[DEBUG] globi url: ", url );
    fetch( url ).then(
      response => {
        response.json( ).then( interactions => {
          const inatTaxonIds = _.uniq( interactions.map( interaction =>
            interaction.target_taxon_external_id.split( ":" )[1] ) );
          iNaturalistJS.taxa.fetch( inatTaxonIds ).then( taxaResponse => {
            const nodes = taxaResponse.results;
            const links = interactions.map( interaction => {
              // console.log( "[DEBUG] taxon.id: ", taxon.id );
              // console.log( "[DEBUG] target: ", parseInt( interaction.target_taxon_external_id.split( ":" )[1], 0 ) );
              return {
                sourceId: taxon.id,
                targetId: parseInt( interaction.target_taxon_external_id.split( ":" )[1], 0 )
              };
            } );
            // console.log( "[DEBUG] links[0]: ", links[0] );
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
