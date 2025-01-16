import _ from "lodash";
import moment from "moment-timezone";
import update from "immutability-helper";
import inaturalistjs from "inaturalistjs";
import DroppedFile from "../../../observations/uploader/models/dropped_file";
import ObsCard from "../../../observations/uploader/models/obs_card";
import { parsableDatetimeFormat } from "../../../observations/uploader/models/util";

const RESET_STATE = "computer_vision_eval/RESET_STATE";
const SET_LOCATION_CHOOSER = "computer_vision_eval/SET_LOCATION_CHOOSER";
const SET_OBS_CARD = "computer_vision_eval/SET_OBS_CARD";
const SET_HOVER_RESULT = "computer_vision_eval/SET_HOVER_RESULT";
const UPDATE_STATE = "computer_vision_eval/UPDATE_STATE";
const UPDATE_OBS_CARD = "computer_vision_eval/UPDATE_OBS_CARD";
const UPDATE_API_RESPONSE = "computer_vision_eval/UPDATE_API_RESPONSE";
const SET_ATTRIBUTES = "computer_vision_eval/SET_ATTRIBUTES";

const DEFAULT_STATE = {
  obsCard: { },
  locationChooser: { },
  hoverResult: null,
  apiResponse: { },
  toggleableSettings: {
    openTaxonCombinedThreshold: 0.1,
    scoreCutoffRatio: 0.01,
    maxResultsToConsider: 15
  },
  filteredResults: [],
  filteredResultLeaves: []
};

export default function reducer( state = DEFAULT_STATE, action ) {
  let modified;
  switch ( action.type ) {
    case RESET_STATE:
      window.scrollTo( 0, 0 );
      return { ...DEFAULT_STATE };
    case SET_LOCATION_CHOOSER:
      return { ...state, locationChooser: action.attrs };
    case SET_OBS_CARD:
      return { ...state, obsCard: action.obsCard };
    case SET_HOVER_RESULT:
      return { ...state, hoverResult: action.result };
    case UPDATE_API_RESPONSE:
      return { ...state, apiResponse: action.apiResponse };
    case UPDATE_STATE:
      modified = { ...state };
      _.each( action.newState, ( val, attr ) => {
        modified = update( modified, {
          [attr]: { $merge: val }
        } );
      } );
      return modified;
    case UPDATE_OBS_CARD:
      return {
        ...state,
        obsCard: {
          ...state.obsCard,
          ...action.obsCard
        }
      };
    case SET_ATTRIBUTES:
      return { ...state, ...action.attributes };
    default:
  }
  return state;
}

export function resetState( ) {
  history.pushState( { }, "Computer Vision Eval", "/computer_vision_eval" );
  return { type: RESET_STATE };
}

export function setObsCard( obsCard ) {
  return {
    type: SET_OBS_CARD,
    obsCard
  };
}

export function updateState( newState ) {
  return {
    type: UPDATE_STATE,
    newState
  };
}
export function setLocationChooser( attrs ) {
  return {
    type: SET_LOCATION_CHOOSER,
    attrs
  };
}

export function updateObsCard( obsCard ) {
  return {
    type: UPDATE_OBS_CARD,
    obsCard
  };
}

export function setAPIResponse( apiResponse ) {
  return {
    type: UPDATE_API_RESPONSE,
    apiResponse
  };
}

export function setHoverResult( result ) {
  return {
    type: SET_HOVER_RESULT,
    result
  };
}

export function setAttributes( attributes ) {
  return {
    type: SET_ATTRIBUTES,
    attributes
  };
}

const setFilteredTaxa = ( ) => (
  ( dispatch, getState ) => {
    const { computerVisionEval } = getState( );
    const filteredResults = _.filter(
      computerVisionEval.apiResponse.results,
      r => (
        r.normalized_combined_score
          > computerVisionEval.toggleableSettings.openTaxonCombinedThreshold
      )
    );
    const filteredTaxonParents = _.compact( _.uniq(
      _.map( filteredResults, "parent_id" )
    ) );
    const filteredResultLeaves = _.orderBy( _.reject( filteredResults, r => (
      _.includes( filteredTaxonParents, r.taxon_id )
    ) ), "normalized_combined_score", "desc" );
    dispatch( setAttributes( {
      filteredResults,
      filteredResultLeaves
    } ) );
  }
);

export function updateUserSetting( setting, value ) {
  return dispatch => {
    dispatch( updateState( {
      toggleableSettings: {
        [setting]: value
      }
    } ) );
    dispatch( setFilteredTaxa( ) );
  };
}

export function readFileExif( file ) {
  return function ( dispatch ) {
    file.readExif( ).then( metadata => {
      dispatch( updateObsCard( metadata ) );
    } );
  };
}

export function score( obsCard ) {
  return function ( dispatch ) {
    dispatch( updateObsCard( { visionStatus: "loading" } ) );
    const scoreParams = {
      delegate_ca: true,
      aggregated: true,
      include_representative_photos: true
    };
    if ( obsCard.uploadedFile.file ) {
      scoreParams.image = obsCard.uploadedFile.file;
    } else if ( obsCard.uploadedFile.url ) {
      scoreParams.image_url = obsCard.uploadedFile.url;
    }
    if ( obsCard.selected_date ) {
      scoreParams.observed_on = moment( obsCard.selected_date, "YYYY/MM/DD" ).format( );
    }
    if ( obsCard.selected_taxon ) {
      scoreParams.taxon_id = obsCard.selected_taxon.id;
    }
    if ( obsCard.latitude && obsCard.longitude ) {
      scoreParams.lat = obsCard.latitude;
      scoreParams.lng = obsCard.longitude;
    }

    inaturalistjs.computervision.score_image( scoreParams )
      .then( r => {
        dispatch( updateObsCard( { visionStatus: null } ) );
        dispatch( setAPIResponse( r ) );
        dispatch( setFilteredTaxa( ) );
      } ).catch( e => {
        console.log( ["Error fetching vision response for photo", e] );
      } );
  };
}

export function uploadImage( obsCard ) {
  return async function ( dispatch ) {
    dispatch( updateObsCard( {
      uploadedFile: {
        ...obsCard.uploadedFile,
        uploadState: "uploaded"
      }
    } ) );
  };
}

export function onFileDrop( droppedFiles ) {
  return dispatch => {
    if ( droppedFiles.length === 0 ) { return; }
    dispatch( resetState( ) );
    setTimeout( ( ) => {
      let done;
      droppedFiles.forEach( f => {
        if ( done ) { return; }
        if ( f.type.match( /^image\// ) ) {
          done = true;
          const obsCard = new ObsCard( );
          obsCard.uploadedFile = DroppedFile.fromFile( f );
          dispatch( setObsCard( obsCard ) );
          dispatch( readFileExif( obsCard.uploadedFile ) );
          dispatch( uploadImage( obsCard ) );
        }
      } );
    }, 1 );
  };
}

export function lookupObservation( observationID ) {
  return async dispatch => {
    const response = await inaturalistjs.observations.fetch( observationID );
    if ( response && !_.isEmpty( response.results ) ) {
      const observation = response.results[0];
      history.pushState( { }, "Computer Vision Eval", `/computer_vision_eval?observation_id=${observation.id}` );
      observation.locality_notes = observation.place_guess;
      observation.accuracy = observation.positional_accuracy;
      observation.date = moment.tz(
        observation.time_observed_at,
        observation.observed_time_zone
      ).format( parsableDatetimeFormat( ) );
      observation.selected_data = observation.date;
      if ( observation.taxon && observation.taxon.iconic_taxon_id ) {
        observation.selected_taxon = {
          id: observation.taxon.iconic_taxon_id
        };
      }
      const obsCard = new ObsCard( observation );

      if ( !_.isEmpty( observation.photos ) ) {
        const mediumURL = _.replace( observation.photos[0].url, "square", "medium" );
        obsCard.uploadedFile = {
          uploadState: "uploaded",
          preview: mediumURL,
          url: mediumURL
        };
      }
      dispatch( setObsCard( obsCard ) );
      dispatch( score( obsCard ) );
    }
  };
}

export function fetchAndEvalObservation( observationID ) {
  return async dispatch => {
    await dispatch( setObsCard( { } ) );
    await dispatch( lookupObservation( observationID ) );
  };
}
