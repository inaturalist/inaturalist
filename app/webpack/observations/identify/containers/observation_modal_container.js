import { connect } from "react-redux";
import ObservationModal from "../components/observation_modal";
import {
  hideCurrentObservation,
  addIdentification,
  addComment,
  toggleCaptive,
  toggleReviewed,
  agreeWithCurrentObservation,
  showNextObservation,
  showPrevObservation
} from "../actions";

function mapStateToProps( state ) {
  let images;
  const observation = state.currentObservation.observation;
  if ( observation && observation.photos && observation.photos.length > 0 ) {
    images = observation.photos.map( ( photo ) => ( {
      original: photo.photoUrl( "medium" ),
      zoom: photo.photoUrl( "original" ),
      thumbnail: photo.photoUrl( "square" )
    } ) );
  }
  return Object.assign( {}, { images }, state.currentObservation );
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideCurrentObservation( ) );
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
    }
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationModal );

export default ObservationModalContainer;
