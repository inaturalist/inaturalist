import { connect } from "react-redux";
import ObservationModal from "../components/observation_modal";
import { hideCurrentObservation } from "../actions";

function mapStateToProps( state ) {
  return {
    observation: state.currentObservation.observation,
    visible: state.currentObservation.visible
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideCurrentObservation( ) );
    }
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationModal );

export default ObservationModalContainer;
