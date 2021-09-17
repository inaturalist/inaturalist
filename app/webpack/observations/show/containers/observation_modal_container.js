import { connect } from "react-redux";
import { updateCurrentUser } from "../../../shared/ducks/config";
import ObservationModal from "../../identify/components/observation_modal";
import { addID } from "../ducks/observation";
import {
  hideCurrentObservation,
  updateCurrentObservation
} from "../../identify/actions/current_observation_actions";
import {
  increaseBrightness,
  decreaseBrightness,
  resetBrightness
} from "../../identify/ducks/brightnesses";

function mapStateToProps( state ) {
  let images;
  const { observation } = state;
  if ( observation && observation.photos && observation.photos.length > 0 ) {
    let defaultPhotoSize = "medium";
    if ( $( ".ObservationModal .image-gallery" ).width( ) > 600 ) {
      defaultPhotoSize = "large";
    }
    images = observation.photos.map( photo => ( {
      original: photo.photoUrl( defaultPhotoSize ),
      zoom: photo.photoUrl( "original" ),
      thumbnail: photo.photoUrl( "square" ),
      originalDimensions: photo.original_dimensions
    } ) );
  }
  const currentObsBrightnessKeys = {};
  const brightnessKeys = Object.keys( state.brightnesses );
  const id = observation && observation.id;
  brightnessKeys.forEach( key => {
    if ( key.includes( id ) ) {
      currentObsBrightnessKeys[key] = state.brightnesses[key];
    }
  } );
  return Object.assign( {}, {
    images,
    brightnesses: currentObsBrightnessKeys,
    currentUser: state.config.currentUser,
    tab: "suggestions",
    tabs: ["suggestions"],
    tabTitles: { suggestions: I18n.t( "compare" ) },
    hidePrevNext: true,
    hideTools: true
  }, state.currentObservation );
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideCurrentObservation( ) );
    },
    setImagesCurrentIndex: index => {
      dispatch( updateCurrentObservation( { imagesCurrentIndex: index } ) );
    },
    chooseSuggestedTaxon: ( taxon, options ) => {
      dispatch( addID( Object.assign( {}, taxon, { isVisionResult: options.vision } ) ) );
      dispatch( hideCurrentObservation( ) );
    },
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) ),
    increaseBrightness: ( ) => dispatch( increaseBrightness( ) ),
    decreaseBrightness: ( ) => dispatch( decreaseBrightness( ) ),
    resetBrightness: ( ) => dispatch( resetBrightness( ) )
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationModal );

export default ObservationModalContainer;
