import _ from "lodash";
import moment from "moment-timezone";
import inaturalistjs from "inaturalistjs";
import DroppedFile from "../../../observations/uploader/models/dropped_file";
import { parsableDatetimeFormat } from "../../../observations/uploader/models/util";
import { normalizeAnnotations } from "../util/annotations_api";

const RESET_STATE = "annotation_eval/RESET_STATE";
const SET_ATTRIBUTES = "annotation_eval/SET_ATTRIBUTES";
const UPDATE_OBS_CARD = "annotation_eval/UPDATE_OBS_CARD";

const DEFAULT_STATE = {
  obsCard: null,
  species: null,
  speciesSource: null,
  visionSpecies: null,
  status: null,
  annotations: null,
  annotationsMeta: null,
  rawResponse: null,
  error: null
};

export default function reducer( state = DEFAULT_STATE, action ) {
  switch ( action.type ) {
    case RESET_STATE:
      window.scrollTo( 0, 0 );
      return { ...DEFAULT_STATE };
    case SET_ATTRIBUTES:
      return { ...state, ...action.attributes };
    case UPDATE_OBS_CARD:
      return { ...state, obsCard: { ...state.obsCard, ...action.attributes } };
    default:
      return state;
  }
}

export function setAttributes( attributes ) {
  return { type: SET_ATTRIBUTES, attributes };
}

export function updateObsCard( attributes ) {
  return { type: UPDATE_OBS_CARD, attributes };
}

export function resetState( ) {
  history.pushState( { }, "Annotation Eval", "/annotation_eval" );
  return { type: RESET_STATE };
}

const resolveAnnotationTaxon = async response => {
  const commonAncestor = response.common_ancestor && response.common_ancestor.taxon;
  const annotationTaxonID = response.annotations && response.annotations.taxon_id;
  if ( !annotationTaxonID ) {
    const topLeaf = _.first( _.orderBy(
      _.filter( response.results, r => r.right === r.left + 1 ),
      "combined_score",
      "desc"
    ) );
    return commonAncestor || ( topLeaf && topLeaf.taxon ) || null;
  }
  if ( commonAncestor && commonAncestor.id === annotationTaxonID ) {
    return commonAncestor;
  }
  const match = _.find( response.results, r => r.taxon && r.taxon.id === annotationTaxonID );
  if ( match ) { return match.taxon; }
  try {
    const lookup = await inaturalistjs.taxa.fetch( annotationTaxonID );
    return _.first( lookup.results ) || null;
  } catch ( e ) {
    // eslint-disable-next-line no-console
    console.warn( `Could not look up annotation taxon ${annotationTaxonID}`, e );
    return commonAncestor || null;
  }
};

const requestScores = ( { annotationTaxonID = null, keepSpecies = false } = { } ) => (
  async ( dispatch, getState ) => {
    const { obsCard } = getState( ).annotationEval;
    if ( !obsCard ) { return; }
    dispatch( setAttributes( { status: "loading", error: null } ) );

    const params = { aggregated: true, annotations: true };
    if ( obsCard.file ) {
      params.image = obsCard.file;
    } else if ( obsCard.photoURL ) {
      params.image_url = obsCard.photoURL;
    }
    if ( obsCard.observedOn ) {
      params.observed_on = obsCard.observedOn;
    }
    if ( obsCard.latitude && obsCard.longitude ) {
      params.lat = obsCard.latitude;
      params.lng = obsCard.longitude;
    }
    if ( annotationTaxonID ) {
      params.annotation_taxon_id = annotationTaxonID;
    }

    let response;
    try {
      response = await inaturalistjs.computervision.score_image( params );
    } catch ( e ) {
      // eslint-disable-next-line no-console
      console.error( "Error scoring image", e );
      dispatch( setAttributes( {
        status: "failed",
        rawResponse: null,
        error: "Could not score this photo"
      } ) );
      return;
    }

    const attributes = { status: null, rawResponse: response };

    if ( !keepSpecies ) {
      const taxon = await resolveAnnotationTaxon( response );
      attributes.species = taxon;
      attributes.visionSpecies = taxon;
      attributes.speciesSource = taxon ? "vision" : null;
    }

    attributes.annotations = normalizeAnnotations( response.annotations );
    attributes.annotationsMeta = response.annotations
      ? _.omit( response.annotations, ["attributes"] )
      : null;

    dispatch( setAttributes( attributes ) );
  }
);

export function evaluate( ) {
  return requestScores( );
}

export function rescore( ) {
  return ( dispatch, getState ) => {
    const { species, speciesSource } = getState( ).annotationEval;
    return dispatch( requestScores( {
      annotationTaxonID: species ? species.id : null,
      keepSpecies: speciesSource === "manual"
    } ) );
  };
}

export function setSpecies( taxon ) {
  return ( dispatch, getState ) => {
    const { species } = getState( ).annotationEval;
    if ( ( species && species.id ) === ( taxon && taxon.id ) ) { return null; }
    dispatch( setAttributes( { species: taxon, speciesSource: taxon ? "manual" : null } ) );
    return dispatch( requestScores( {
      annotationTaxonID: taxon ? taxon.id : null,
      keepSpecies: true
    } ) );
  };
}

export function revertSpecies( ) {
  return ( dispatch, getState ) => {
    const { visionSpecies } = getState( ).annotationEval;
    dispatch( setAttributes( { species: visionSpecies, speciesSource: "vision" } ) );
    return dispatch( requestScores( {
      annotationTaxonID: visionSpecies ? visionSpecies.id : null,
      keepSpecies: true
    } ) );
  };
}

export function onFileDrop( droppedFiles ) {
  return dispatch => {
    const file = _.first( _.filter( droppedFiles, f => f.type.match( /^image\// ) ) );
    if ( !file ) { return; }
    dispatch( resetState( ) );
    const droppedFile = DroppedFile.fromFile( file );
    dispatch( setAttributes( {
      obsCard: {
        file,
        photoPreview: file.preview,
        name: file.name
      }
    } ) );
    droppedFile.readExif( ).then( metadata => {
      dispatch( updateObsCard( {
        date: metadata.date,
        observedOn: metadata.date,
        latitude: metadata.latitude,
        longitude: metadata.longitude,
        localityNotes: metadata.locality_notes
      } ) );
    } );
    dispatch( evaluate( ) );
  };
}

export function lookupObservation( observationID ) {
  return async dispatch => {
    dispatch( resetState( ) );
    dispatch( setAttributes( { status: "loading" } ) );
    let observation;
    try {
      const response = await inaturalistjs.observations.fetch( observationID );
      observation = _.first( response.results );
    } catch ( e ) {
      // eslint-disable-next-line no-console
      console.error( "Error fetching observation", e );
    }
    if ( !observation ) {
      dispatch( setAttributes( {
        status: null,
        error: `Could not load observation ${observationID}`
      } ) );
      return;
    }
    history.pushState( { }, "Annotation Eval", `/annotation_eval?observation_id=${observation.id}` );
    const photoURL = _.isEmpty( observation.photos )
      ? null
      : _.replace( _.first( observation.photos ).url, "square", "medium" );
    const date = observation.time_observed_at
      ? moment.tz( observation.time_observed_at, observation.observed_time_zone )
        .format( parsableDatetimeFormat( ) )
      : observation.observed_on_string || observation.observed_on;
    dispatch( setAttributes( {
      obsCard: {
        observationID: observation.id,
        photoURL,
        photoPreview: photoURL,
        date,
        observedOn: observation.observed_on,
        latitude: observation.geojson ? observation.geojson.coordinates[1] : null,
        longitude: observation.geojson ? observation.geojson.coordinates[0] : null,
        localityNotes: observation.place_guess
      }
    } ) );
    dispatch( evaluate( ) );
  };
}
