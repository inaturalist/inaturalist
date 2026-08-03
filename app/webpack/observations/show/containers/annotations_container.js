import { connect } from "react-redux";
import Annotations from "../components/annotations";
import AnnotationsLegacy from "../components/annotations_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { fetchControlledTerms } from "../ducks/controlled_terms";
import {
  addAnnotation,
  deleteAnnotation,
  voteAnnotation,
  unvoteAnnotation
} from "../ducks/observation";
import { updateSession } from "../ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config,
    controlledTerms: state.controlledTerms.terms,
    loading: !state.controlledTerms.loaded,
    open: state.controlledTerms.open
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addAnnotation: ( controlledAttribute, controlledValue ) => {
      dispatch( addAnnotation( controlledAttribute, controlledValue ) );
    },
    deleteAnnotation: id => { dispatch( deleteAnnotation( id ) ); },
    voteAnnotation: ( id, vote ) => { dispatch( voteAnnotation( id, vote ) ); },
    unvoteAnnotation: id => { dispatch( unvoteAnnotation( id ) ); },
    updateSession: params => { dispatch( updateSession( params ) ); },
    fetchControlledTerms: ( ) => { dispatch( fetchControlledTerms( ) ); }
  };
}

const AnnotationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, Annotations, AnnotationsLegacy ) );

export default AnnotationsContainer;
