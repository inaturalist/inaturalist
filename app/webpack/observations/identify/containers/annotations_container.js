import { connect } from "react-redux";
import Annotations from "../../show/components/annotations";
import {
  addAnnotation,
  deleteAnnotation,
  voteAnnotation,
  unvoteAnnotation
} from "../actions/current_observation_actions";
import { updateSession } from "../../show/ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.currentObservation.observation,
    config: state.config,
    controlledTerms: state.controlledTerms.allTerms,
    collapsible: false
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addAnnotation: ( controlledAttribute, controlledValue ) => {
      dispatch( addAnnotation( controlledAttribute, controlledValue ) );
    },
    deleteAnnotation: id => dispatch( deleteAnnotation( id ) ),
    voteAnnotation: ( id, vote ) => {
      dispatch( voteAnnotation( id, vote ) );
    },
    unvoteAnnotation: id => dispatch( unvoteAnnotation( id ) ),
    updateSession: params => { dispatch( updateSession( params ) ); }
  };
}

const AnnotationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Annotations );

export default AnnotationsContainer;
