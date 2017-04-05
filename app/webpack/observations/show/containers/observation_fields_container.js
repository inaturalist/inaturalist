import { connect } from "react-redux";
import ObservationFields from "../components/observation_fields";
import { addObservationFieldValue, removeObservationFieldValue } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addObservationFieldValue: options => { dispatch( addObservationFieldValue( options ) ); },
    removeObservationFieldValue: id => { dispatch( removeObservationFieldValue( id ) ); }
  };
}

const ObservationFieldsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationFields );

export default ObservationFieldsContainer;
