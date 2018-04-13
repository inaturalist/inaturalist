import { connect } from "react-redux";
import ObservationFields from "../components/observation_fields";
import { addObservationFieldValue, removeObservationFieldValue,
  updateObservationFieldValue } from "../ducks/observation";
import { updateSession } from "../ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addObservationFieldValue: options => { dispatch( addObservationFieldValue( options ) ); },
    removeObservationFieldValue: id => { dispatch( removeObservationFieldValue( id ) ); },
    updateObservationFieldValue: ( id, options ) => {
      dispatch( updateObservationFieldValue( id, options ) );
    },
    updateSession: params => { dispatch( updateSession( params ) ); }
  };
}

const ObservationFieldsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationFields );

export default ObservationFieldsContainer;
