import { connect } from "react-redux";
import ComputerVisionDemoApp from "../components/computer_vision_demo_app";
import { onFileDrop, updateObsCard, score, updateState, setLocationChooser, resetState } from
  "../ducks/computer_vision_demo";

const mapStateToProps = ( state ) => state.computerVisionDemo;

const mapDispatchToProps = ( dispatch ) => ( {
  onFileDrop: droppedFiles => {
    dispatch( onFileDrop( droppedFiles ) );
  },
  updateObsCard: attrs => {
    dispatch( updateObsCard( attrs ) );
  },
  score: uuid => {
    dispatch( score( uuid ) );
  },
  resetState: ( ) => {
    dispatch( resetState( ) );
  },
  updateState: newState => {
    dispatch( updateState( newState ) );
  },
  setLocationChooser: attrs => {
    dispatch( setLocationChooser( attrs ) );
  }
} );

const ComputerVisionDemo = connect(
  mapStateToProps,
  mapDispatchToProps
)( ComputerVisionDemoApp );

export default ComputerVisionDemo;
