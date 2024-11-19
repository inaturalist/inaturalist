import { connect } from "react-redux";
import LocationChooser from "../../../observations/uploader/components/location_chooser";
import {
  updateObsCard,
  updateState
} from "../ducks/computer_vision_eval";

const mapStateToProps = state => ( {
  ...state.computerVisionEval.locationChooser,
  updateSingleObsCard: true
} );

const mapDispatchToProps = dispatch => ( {
  updateObsCard: attrs => {
    dispatch( updateObsCard( attrs ) );
  },
  updateState: newState => {
    dispatch( updateState( newState ) );
  }
} );

const LocationChooserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( LocationChooser );

export default LocationChooserContainer;
