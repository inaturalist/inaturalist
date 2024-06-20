import { connect } from "react-redux";
import ComputerVisionEvalApp from "../components/computer_vision_eval_app";
import {
  onFileDrop,
  score,
  resetState,
  lookupObservation
} from "../ducks/computer_vision_eval";

const mapStateToProps = state => state.computerVisionEval;

const mapDispatchToProps = dispatch => ( {
  onFileDrop: droppedFiles => {
    dispatch( onFileDrop( droppedFiles ) );
  },
  score: obsCard => {
    dispatch( score( obsCard ) );
  },
  resetState: ( ) => {
    dispatch( resetState( ) );
  },
  lookupObservation: observationID => {
    dispatch( lookupObservation( observationID ) );
  }
} );

const ComputerVisionEvalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ComputerVisionEvalApp );

export default ComputerVisionEvalContainer;
