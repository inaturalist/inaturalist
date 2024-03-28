import { connect } from "react-redux";
import ObsCardComponent from "../components/obs_card_component";
import {
  updateObsCard,
  setLocationChooser,
  resetState
} from "../ducks/computer_vision_eval";

const mapStateToProps = state => state.computerVisionEval;

const mapDispatchToProps = dispatch => ( {
  updateObsCard: attrs => {
    dispatch( updateObsCard( attrs ) );
  },
  setLocationChooser: attrs => {
    dispatch( setLocationChooser( attrs ) );
  },
  resetState: ( ) => {
    dispatch( resetState( ) );
  }
} );

const ObsCardContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObsCardComponent );

export default ObsCardContainer;
