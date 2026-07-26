import { connect } from "react-redux";
import AnnotationEvalApp from "../components/annotation_eval_app";
import {
  onFileDrop,
  lookupObservation,
  rescore,
  resetState
} from "../ducks/annotation_eval";

const mapStateToProps = state => state.annotationEval;

const mapDispatchToProps = dispatch => ( {
  onFileDrop: droppedFiles => dispatch( onFileDrop( droppedFiles ) ),
  lookupObservation: observationID => dispatch( lookupObservation( observationID ) ),
  rescore: ( ) => dispatch( rescore( ) ),
  resetState: ( ) => dispatch( resetState( ) )
} );

export default connect( mapStateToProps, mapDispatchToProps )( AnnotationEvalApp );
