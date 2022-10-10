import { connect } from "react-redux";
import { updateCurrentUser, setConfig } from "../../../shared/ducks/config";
import ObservationModal from "../components/observation_modal";
import { updateEditorContent } from "../../shared/ducks/text_editors";
import {
  hideCurrentObservation,
  addIdentification,
  addComment,
  toggleCaptive,
  toggleReviewed,
  agreeWithCurrentObservation,
  showNextObservation,
  showPrevObservation,
  updateCurrentObservation,
  fetchDataForTab,
  chooseSuggestedTaxon
} from "../actions";
import {
  increaseBrightness,
  decreaseBrightness,
  resetBrightness
} from "../ducks/brightnesses";

function mapStateToProps( state ) {
  let images;
  const { observation } = state.currentObservation;
  if ( observation && observation.photos && observation.photos.length > 0 ) {
    let defaultPhotoSize = "medium";
    if ( $( ".image-gallery" ).width( ) > 600 ) {
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

  return {
    images,
    blind: state.config.blind,
    brightnesses: currentObsBrightnessKeys,
    controlledTerms: state.controlledTerms.terms,
    currentUser: state.config.currentUser,
    mapZoomLevel: state.config.mapZoomLevel,
    mapZoomLevelLocked: state.config.mapZoomLevelLocked === undefined
      ? false
      : state.config.mapZoomLevelLocked,
    officialAppIds: state.config.officialAppIds === undefined
      ? []
      : state.config.officialAppIds,
    ...state.currentObservation
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideCurrentObservation( ) );
      dispatch( updateEditorContent( "obsIdentifyIdComment", "" ) );
    },
    toggleCaptive: ( ) => {
      dispatch( toggleCaptive( ) );
    },
    toggleReviewed: ( ) => {
      dispatch( toggleReviewed( ) );
    },
    addIdentification: ( ) => {
      dispatch( addIdentification( ) );
    },
    addComment: ( ) => {
      dispatch( addComment( ) );
    },
    agreeWithCurrentObservation: ( ) => {
      dispatch( agreeWithCurrentObservation( ) ).then( ( ) => {
        $( ".ObservationModal:first" ).find( ".sidebar" ).scrollTop( $( window ).height( ) );
      } );
    },
    showNextObservation: ( ) => {
      dispatch( showNextObservation( ) );
    },
    showPrevObservation: ( ) => {
      dispatch( showPrevObservation( ) );
    },
    chooseTab: tab => {
      dispatch( updateCurrentObservation( { tab } ) );
      dispatch( fetchDataForTab( ) );
    },
    setImagesCurrentIndex: index => {
      dispatch( updateCurrentObservation( { imagesCurrentIndex: index } ) );
    },
    toggleKeyboardShortcuts: keyboardShortcutsShown => {
      dispatch( updateCurrentObservation( { keyboardShortcutsShown: !keyboardShortcutsShown } ) );
    },
    chooseSuggestedTaxon: ( taxon, options = {} ) => dispatch(
      chooseSuggestedTaxon( taxon, options )
    ),
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) ),
    updateEditorContent: ( editor, content ) => dispatch( updateEditorContent( "obsIdentifyIdComment", content ) ),
    onMapZoomChanged: ( e, map ) => dispatch( setConfig( { mapZoomLevel: map.getZoom( ) } ) ),
    setMapZoomLevelLocked: locked => dispatch( setConfig( { mapZoomLevelLocked: locked } ) ),
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
