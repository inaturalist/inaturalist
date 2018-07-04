import { connect } from "react-redux";
import ObservationModal from "../../identify/components/observation_modal";
import {
  hideCurrentObservation,
  addIdentification,
  // addComment,
  // toggleCaptive,
  // toggleReviewed,
  // agreeWithCurrentObservation,
  // showNextObservation,
  // showPrevObservation,
  updateCurrentObservation,
  fetchDataForTab
} from "../../identify/actions/current_observation_actions";

function mapStateToProps( state ) {
  let images;
  const observation = state.observation;
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
  return Object.assign( {}, {
    images,
    currentUser: state.config.currentUser,
    tab: "suggestions",
    tabs: ["suggestions"],
    hidePrevNext: true,
    hideTools: true
  }, state.currentObservation );
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideCurrentObservation( ) );
    },
    // toggleCaptive: ( ) => {
    //   dispatch( toggleCaptive( ) );
    // },
    // toggleReviewed: ( ) => {
    //   dispatch( toggleReviewed( ) );
    // },
    addIdentification: ( ) => {
      dispatch( addIdentification( ) );
    },
    // addComment: ( ) => {
    //   dispatch( addComment( ) );
    // },
    // agreeWithCurrentObservation: ( ) => {
    //   dispatch( agreeWithCurrentObservation( ) ).then( ( ) => {
    //     $( ".ObservationModal:first" ).find( ".sidebar" ).scrollTop( $( window ).height( ) );
    //   } );
    // },
    // showNextObservation: ( ) => {
    //   dispatch( showNextObservation( ) );
    // },
    // showPrevObservation: ( ) => {
    //   dispatch( showPrevObservation( ) );
    // },
    chooseTab: ( tab ) => {
      dispatch( updateCurrentObservation( { tab } ) );
      dispatch( fetchDataForTab( ) );
    },
    setImagesCurrentIndex: index => {
      dispatch( updateCurrentObservation( { imagesCurrentIndex: index } ) );
    }
    // toggleKeyboardShortcuts: keyboardShortcutsShown => {
    //   dispatch( updateCurrentObservation( { keyboardShortcutsShown: !keyboardShortcutsShown } ) );
    // }
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationModal );

export default ObservationModalContainer;
