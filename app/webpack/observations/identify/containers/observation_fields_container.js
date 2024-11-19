import { connect } from "react-redux";
import Annotations from "../../show/components/observation_fields";
import {
  addObservationFieldValue,
  removeObservationFieldValue,
  updateObservationFieldValue
} from "../actions/current_observation_actions";
import { updateSession } from "../../show/ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.currentObservation.observation,
    config: state.config,
    placeholder: I18n.t( "add_a_field" ),
    context: "identify"
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

const AnnotationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Annotations );

export default AnnotationsContainer;
