import { connect } from "react-redux";
import ObservationModal from "../components/observation_modal";
import {
  hideCurrentObservation,
  addIdentification,
  addComment,
  toggleCaptive,
  toggleReviewed
} from "../actions";

function mapStateToProps( state ) {
  let images;
  const observation = state.currentObservation.observation;
  if ( observation ) {
    images = observation.photos.map( ( photo ) => ( {
      original: photo.photoUrl( "large" ),
      thumbnail: photo.photoUrl( "thumb" )
    } ) );
  }
  return {
    observation,
    visible: state.currentObservation.visible,
    images,
    commentFormVisible: state.currentObservation.commentFormVisible,
    identificationFormVisible: state.currentObservation.identificationFormVisible,
    // TODO i think the process of adding the currentObservation to the state
    // needs to load these extra bits of data
    reviewedByCurrentUser: state.currentObservation.reviewedByCurrentUser,
    captiveByCurrentUser: state.currentObservation.captiveByCurrentUser
  };
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
    }
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationModal );

export default ObservationModalContainer;
