import inatjs from "inaturalistjs";
import moment from "moment";
import querystring from "querystring";
import _ from "lodash";
import { fetch } from "../../../shared/util";
import { defaultObservationParams } from "../util";

const SET_TAXON = "taxa-show/taxon/SET_TAXON";
const SET_DESCRIPTION = "taxa-show/taxon/SET_DESCRIPTION";
const SET_LINKS = "taxa-show/taxon/SET_LINKS";
const SET_COUNT = "taxa-show/taxon/SET_COUNT";
const SET_NAMES = "taxa-show/taxon/SET_NAMES";
const SET_INTERACTIONS = "taxa-show/taxon/SET_INTERACTIONS";
const SET_TRENDING = "taxa-show/taxon/SET_TRENDING";
const SET_RARE = "taxa-show/taxon/SET_RARE";
const SET_RECENT = "taxa-show/taxon/SET_RECENT";
const SET_WANTED = "taxa-show/taxon/SET_WANTED";
const SET_SIMILAR = "taxa-show/taxon/SET_SIMILAR";
const SHOW_PHOTO_CHOOSER = "taxa-show/taxon/SHOW_PHOTO_CHOOSER";
const HIDE_PHOTO_CHOOSER = "taxa-show/taxon/HIDE_PHOTO_CHOOSER";
const SET_TAXON_CHANGE = "taxa-show/taxon/SET_TAXON_CHANGE";
const SET_FIELD_VALUES = "taxa-show/taxon/SET_FIELD_VALUES";
const SET_SPECIES = "taxa-show/taxon/SET_SPECIES";

export default function reducer( state = { counts: {} }, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SET_TAXON:
      newState.taxon = action.taxon;
      newState.taxonPhotos = _.uniqBy( newState.taxon.taxonPhotos, tp => tp.photo.id );
      newState.counts = {};
      delete newState.description;
      delete newState.fieldValues;
      delete newState.interactions;
      delete newState.links;
      delete newState.names;
      delete newState.rare;
      delete newState.recent;
      delete newState.similar;
      delete newState.species;
      delete newState.taxonChange;
      delete newState.trending;
      delete newState.wanted;
      break;
    case SET_DESCRIPTION:
      newState.description = {
        source: action.source,
        url: action.url,
        body: action.body
      };
      break;
    case SET_LINKS:
      newState.links = action.links;
      break;
    case SET_COUNT:
      newState.counts = state.counts || {};
      newState.counts[action.count] = action.value;
      break;
    case SET_NAMES:
      newState.names = action.names;
      break;
    case SET_INTERACTIONS:
      newState.interactions = action.interactions;
      break;
    case SET_TRENDING:
      newState.trending = action.taxa;
      break;
    case SET_RARE:
      newState.rare = action.taxa;
      break;
    case SET_RECENT:
      newState.recent = action.response;
      break;
    case SET_SIMILAR:
      newState.similar = action.results;
      break;
    case SET_WANTED:
      newState.wanted = action.taxa;
      break;
    case SHOW_PHOTO_CHOOSER:
      newState.photoChooserVisible = true;
      break;
    case HIDE_PHOTO_CHOOSER:
      newState.photoChooserVisible = false;
      break;
    case SET_TAXON_CHANGE:
      newState.taxonChange = action.taxonChange;
      break;
    case SET_FIELD_VALUES:
      newState.fieldValues = action.fieldValues;
      break;
    case SET_SPECIES:
      newState.species = action.response;
      break;
    default:
      // nothing to see here
  }
  return newState;
}

export function setTaxon( taxon ) {
  return {
    type: SET_TAXON,
    taxon
  };
}

export function setDescription( source, url, body ) {
  return {
    type: SET_DESCRIPTION,
    source,
    url,
    body
  };
}

export function setLinks( links ) {
  return {
    type: SET_LINKS,
    links
  };
}

export function setCount( count, value ) {
  return {
    type: SET_COUNT,
    count,
    value
  };
}

export function setNames( names ) {
  return {
    type: SET_NAMES,
    names
  };
}

export function setInteractions( interactions ) {
  return {
    type: SET_INTERACTIONS,
    interactions
  };
}

export function setTrending( taxa ) {
  return {
    type: SET_TRENDING,
    taxa
  };
}

export function setRare( taxa ) {
  return {
    type: SET_RARE,
    taxa
  };
}

export function setRecent( response ) {
  return {
    type: SET_RECENT,
    response
  };
}

export function setWanted( taxa ) {
  return {
    type: SET_WANTED,
    taxa
  };
}

export function setSimilar( results ) {
  return {
    type: SET_SIMILAR,
    results
  };
}

export function showPhotoChooser( ) {
  return { type: SHOW_PHOTO_CHOOSER };
}

export function hidePhotoChooser( ) {
  return { type: HIDE_PHOTO_CHOOSER };
}

export function setTaxonChange( taxonChange ) {
  return { type: SET_TAXON_CHANGE, taxonChange };
}

export function showPhotoChooserIfSignedIn( ) {
  return ( dispatch, getState ) => {
    const { currentUser } = getState( ).config;
    const signedIn = currentUser && currentUser.id;
    if ( signedIn ) {
      dispatch( showPhotoChooser( ) );
    } else {
      window.location = `/login?return_to=${window.location}`;
    }
  };
}

export function fetchTerms( options = { histograms: false } ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const params = { taxon_id: s.taxon.taxon.id, per_page: 50 };
    if ( s.config.chosenPlace ) {
      params.place_id = s.config.chosenPlace.id;
    }
    if ( options.histograms ) {
      params.unannotated = true;
    } else {
      params.no_histograms = true;
    }
    return inatjs.observations.popularFieldValues( params ).then( r => {
      const controlledAttributes = _.reduce( r.results, ( memo, result ) => {
        memo[result.controlled_attribute.id] = result.controlled_attribute;
        return memo;
      }, {} );
      const relevantResults = _.filter( r.results, f => (
        !f.controlled_attribute.taxon_ids
        || _.intersection(
          s.taxon.taxon.ancestor_ids,
          f.controlled_attribute.taxon_ids
        ).length > 0
        || f.controlled_attribute.taxon_ids.length === 0
      ) );
      const fieldValues = _.groupBy( relevantResults, f => f.controlled_attribute.id );
      if ( options.histograms ) {
        _.each( r.unannotated, ( data, controlledAttributeId ) => {
          fieldValues[Number( controlledAttributeId )].push( {
            count: data.count,
            month_of_year: data.month_of_year,
            controlled_attribute: controlledAttributes[Number( controlledAttributeId )],
            controlled_value: {
              label: "No Annotation"
            }
          } );
        } );
      }
      dispatch( {
        type: SET_FIELD_VALUES,
        fieldValues
      } );
    } ).catch( e => { console.log( e ); } );
  };
}

export function setSpecies( response ) {
  return { type: SET_SPECIES, response };
}

export function fetchSpecies( taxon, options = { } ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = taxon || s.taxon.taxon;
    const params = Object.assign( { }, options, {
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale,
      taxon_id: t.id,
      rank: "species,subspecies,variety",
      verifiable: true,
      taxon_is_active: true,
      per_page: 0
    } );
    return inatjs.observations.speciesCounts( params ).then( response => {
      dispatch( setSpecies( response ) );
    } );
  };
}

export function fetchTaxon( taxon, options = { } ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = taxon || s.taxon.taxon;
    const params = Object.assign( { }, options, {
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale
    } );
    return inatjs.taxa.fetch( t.id, params ).then( response => {
      // make sure the charts revert back to the "Seasonality" tab
      // in case the incoming results have no data for the current tab
      $( "a[href='#charts-seasonality']" ).tab( "show" );
      dispatch( setTaxon( response.results[0] ) );
      dispatch( fetchTerms( ) );
    } );
  };
}

export function fetchDescription( ) {
  return ( dispatch, getState ) => {
    const { taxon } = getState( ).taxon;
    let url = `/taxa/${taxon.id}/description`;
    if ( I18n.locale.match( /^en/ ) ) {
      url += "?wiki_prompt=true";
    }
    fetch( url ).then(
      response => {
        const source = response.headers.get( "X-Describer-Name" );
        const describerUrl = response.headers.get( "X-Describer-URL" );
        response.text( ).then( body => {
          if ( body && body.length > 0 ) {
            dispatch( setDescription( source, describerUrl, body ) );
          }
        } );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchLinks( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { taxon } = s.taxon;
    let url = `/taxa/${taxon.id}/links.json`;
    if ( s.config.preferredPlace ) {
      url += `?place_id=${s.config.preferredPlace.id}`;
    }
    fetch( url ).then(
      response => {
        response.json( ).then( json => dispatch( setLinks( json ) ) );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchNames( taxon ) {
  return ( dispatch, getState ) => {
    const t = taxon || getState( ).taxon.taxon;
    fetch( `/taxon_names.json?per_page=200&taxon_id=${t.id}` ).then(
      response => {
        response.json( ).then( json => dispatch( setNames( json ) ) );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchInteractions( taxon ) {
  return ( dispatch, getState ) => {
    const t = taxon || getState( ).taxon.taxon;
    const params = {
      sourceTaxon: t.name,
      type: "json.v2",
      accordingTo: "iNaturalist"
    };
    const url = `https://api.globalbioticinteractions.org/interaction?${querystring.stringify( params )}`;
    fetch( url ).then(
      response => {
        response.json( ).then( json => dispatch( setInteractions( json ) ) );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchTrending( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      d1: moment( ).subtract( 1, "month" ).format( "YYYY-MM-DD" ),
      taxon_is_active: true
    } );
    inatjs.observations.speciesCounts( params ).then(
      response => dispatch( setTrending( response.results.map( r => r.taxon ) ) ),
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchRare( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      order: "asc",
      csi: "CR,EN",
      taxon_is_active: true
    } );
    inatjs.observations.speciesCounts( params ).then(
      response => dispatch( setRare( response.results.map( r => r.taxon ) ) ),
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchRecent( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( state.observations && state.observations.recent ) {
      return;
    }
    const params = Object.assign( { }, defaultObservationParams( state ), {
      quality_grade: "needs_id,research",
      rank: "species",
      category: "improving,leading",
      per_page: 12
    } );
    const endpoint = inatjs.identifications.recent_taxa;
    endpoint( params ).then(
      response => dispatch( setRecent( response ) ),
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchWanted( ) {
  return ( dispatch, getState ) => {
    const { observations } = getState( );
    if ( observations && observations.wanted ) {
      return;
    }
    const params = {
      id: getState( ).taxon.taxon.id,
      per_page: 12
    };
    inatjs.taxa.wanted( params ).then(
      response => dispatch( setWanted( response.results ) ),
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchSimilar( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const { taxon } = state.taxon;
    const endpoint = inatjs.identifications.similar_species;
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      verifiable: "any"
    } );
    endpoint( params ).then(
      response => {
        const withoutAncestors = response.results
          .filter( r => taxon.ancestor_ids.indexOf( r.taxon.id ) < 0 );
        const commonlyMisidentified = withoutAncestors.filter( r => ( r.count > 1 ) );
        if ( commonlyMisidentified.length === 0 ) {
          dispatch( setSimilar( withoutAncestors ) );
        } else {
          dispatch( setSimilar( commonlyMisidentified ) );
        }
      },
      error => console.log( "[DEBUG] error: ", error )
    );
  };
}

export function updatePhotos( photos ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { taxon } = s.taxon;
    const data = { };
    data.photos = photos.map( photo => ( {
      id: photo.id,
      type: photo.type,
      native_photo_id: photo.native_photo_id
    } ) );
    data.authenticity_token = $( "meta[name=csrf-token]" ).attr( "content" );
    const params = {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify( data )
    };
    fetch( `/taxa/${taxon.id}/set_photos.json`, params )
      .then( ( ) => {
        dispatch( fetchTaxon( s.taxon.taxon, { ttl: -1 } ) );
        dispatch( hidePhotoChooser( ) );
      } );
  };
}

export function fetchTaxonChange( taxon ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const t = taxon || s.taxon.taxon;
    const opts = { headers: { "Content-Type": "application/json" } };
    fetch( `/taxon_changes.json?taxon_id=${t.id}`, opts )
      .then( response => response.json( ) )
      .then( json => {
        if ( !json[0] || _.isEmpty( json[0].input_taxa ) ) {
          return;
        }
        let taxonChange = json[0];
        if ( taxon.is_active ) {
          taxonChange = _.find( json, tc => !tc.committed_on );
        }
        dispatch( setTaxonChange( taxonChange ) );
      } );
  };
}
