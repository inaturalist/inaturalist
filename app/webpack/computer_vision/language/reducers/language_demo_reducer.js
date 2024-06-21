import _ from "lodash";
import update from "immutability-helper";
import inaturalistjs from "inaturalistjs";
import { setConfirmModalState } from "../../../observations/show/ducks/confirm_modal";

const RESET_STATE = "language_demo/RESET_STATE";
const SET_ATTRIBUTES = "language_demo/SET_ATTRIBUTES";
const UPDATE_STATE = "language_demo/UPDATE_STATE";

const DEFAULT_STATE = {
  searchStatus: null,
  searchedTerm: null,
  searchedTaxon: null,
  searchResponse: { },
  lastSearchTime: new Date( ).getTime( ),
  votes: { },
  votingEnabled: false,
  submissionAcknowledged: false,
  iconicTaxa: { }
};

export default function reducer( state = DEFAULT_STATE, action ) {
  let modified;
  switch ( action.type ) {
    case RESET_STATE:
      return { ...DEFAULT_STATE };
    case SET_ATTRIBUTES:
      return Object.assign( { }, state, action.attributes );
    case UPDATE_STATE:
      modified = { ...state };
      _.each( action.newState, ( val, attr ) => {
        modified = update( modified, {
          [attr]: { $merge: val }
        } );
      } );
      return modified;
    default:
  }
  return state;
}

export function resetState( ) {
  return { type: RESET_STATE };
}

export function setAttributes( attributes ) {
  return {
    type: SET_ATTRIBUTES,
    attributes
  };
}

export function updateState( newState ) {
  return {
    type: UPDATE_STATE,
    newState
  };
}

export function toggleVoting( ) {
  return ( dispatch, getState ) => {
    const { languageDemo } = getState( );
    dispatch( setAttributes( {
      votingEnabled: !languageDemo.votingEnabled,
      votes: {}
    } ) );
  };
}

export function languageSearch( searchTerm, searchTaxon, params = { } ) {
  return async dispatch => {
    dispatch( setAttributes( {
      searchStatus: "searching",
      searchedTerm: searchTerm,
      searchedTaxon: searchTaxon,
      submissionAcknowledged: false
    } ) );
    const searchParams = {
      ...params,
      q: searchTerm
    };
    if ( searchTaxon ) {
      searchParams.taxon_id = searchTaxon.id;
    }
    inaturalistjs.computervision.language_search( searchParams ).then( response => {
      // ensure each result has an observation, and the photo is associated with the observation
      response.results = _.filter( response.results, r => {
        if ( _.isEmpty( r.observation ) ) {
          return false;
        }
        if ( !_.includes( _.map( r.observation.photos, "id" ), r.photo_id ) ) {
          return false;
        }
        return true;
      } );
      dispatch( setAttributes( {
        searchStatus: "done",
        searchResponse: response,
        votes: { }
      } ) );
    } ).catch( e => {
      console.log( e );
      dispatch( resetState( ) );
    } );
  };
}

export function nextPage( options = { } ) {
  return async ( dispatch, getState ) => {
    const { languageDemo } = getState( );
    if ( !languageDemo.searchedTerm || languageDemo.searchResponse.page >= 5 ) {
      return;
    }
    if ( options.scrollTop ) {
      $( document ).scrollTop( 0 );
    }
    dispatch( languageSearch( languageDemo.searchedTerm, languageDemo.searchedTaxon, {
      page: languageDemo.searchResponse.page + 1,
      submissionAcknowledged: false
    } ) );
  };
}

export function previousPage( options = { } ) {
  return async ( dispatch, getState ) => {
    const { languageDemo } = getState( );
    if ( !languageDemo.searchedTerm || languageDemo.searchResponse.page === 1 ) {
      return;
    }
    if ( options.scrollTop ) {
      $( document ).scrollTop( 0 );
    }
    dispatch( languageSearch( languageDemo.searchedTerm, languageDemo.searchedTaxon, {
      page: languageDemo.searchResponse.page - 1,
      submissionAcknowledged: false
    } ) );
  };
}

export function voteOnPhoto( photoID, vote ) {
  return ( dispatch, getState ) => {
    const { languageDemo } = getState( );
    if ( _.has( languageDemo.votes, photoID ) && vote === languageDemo.votes[photoID] ) {
      dispatch( setAttributes( {
        votes: _.omit( languageDemo.votes, [photoID] )
      } ) );
      return;
    }
    dispatch( updateState( {
      votes: {
        ...languageDemo.votes,
        [photoID]: ( vote === true )
      }
    } ) );
  };
}

export function fetchIconicTaxa( ) {
  return dispatch => {
    inaturalistjs.taxa.iconic( ).then( r => {
      dispatch( updateState( {
        iconicTaxa: _.keyBy( r.results, "id" )
      } ) );
    } );
  };
}

export function submitVotes( options = { } ) {
  return ( dispatch, getState ) => {
    const { languageDemo, config } = getState( );
    if ( options.scrollTop ) {
      $( document ).scrollTop( 0 );
    }
    const payload = {
      search_term: languageDemo.searchedTerm,
      page: languageDemo.searchResponse.page,
      votes: []
    };
    if ( languageDemo.searchedTaxon ) {
      payload.taxon_id = languageDemo.searchedTaxon.id;
    }
    if ( config.currentUser ) {
      payload.user_id = config.currentUser.id;
    }
    _.each( languageDemo.searchResponse.results, result => {
      const vote = _.has( languageDemo.votes, result.photo_id )
        ? languageDemo.votes[result.photo_id].toString( ) : null;
      payload.votes.push( {
        id: result.photo_id,
        vote,
        score: result.score
      } );
    } );
    fetch( "/language_demo/record_votes", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      },
      body: JSON.stringify( {
        authenticity_token: $( "meta[name=csrf-token]" ).attr( "content" ),
        language_demo_log: payload
      } )
    } );
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "views.nls_demo.thank_you_for_your_submission!" )
    } ) );
  };
}

export function voteRemainingUp( ) {
  return ( dispatch, getState ) => {
    const { languageDemo } = getState( );
    const newVotes = { ...languageDemo.votes };
    _.each( languageDemo.searchResponse.results, result => {
      if ( !_.has( newVotes, result.photo_id ) ) {
        newVotes[result.photo_id] = true;
      }
    } );
    dispatch( updateState( { votes: newVotes } ) );
  };
}

export function voteRemainingDown( ) {
  return ( dispatch, getState ) => {
    const { languageDemo } = getState( );
    const newVotes = { ...languageDemo.votes };
    _.each( languageDemo.searchResponse.results, result => {
      if ( !_.has( newVotes, result.photo_id ) ) {
        newVotes[result.photo_id] = false;
      }
    } );
    dispatch( updateState( { votes: newVotes } ) );
  };
}

export function viewInIdentify( ) {
  return ( dispatch, getState ) => {
    const { languageDemo } = getState( );
    const observationIDs = _.uniq( _.map(
      languageDemo.searchResponse.results,
      r => ( r.observation.id )
    ) );
    const url = `/observations/identify?quality_grade=needs_id,casual,research&reviewed=any&id=${observationIDs.join( "," )}`;
    window.open( url, "_blank", "noopener,noreferrer" );
  };
}

export function acknowledgeSubmission( ) {
  return dispatch => {
    dispatch( setAttributes( {
      votingEnabled: false,
      submissionAcknowledged: true,
      votes: { }
    } ) );
  };
}
