import { connect } from "react-redux";

import ToggleSwitch from "../components/toggle_switch";
import { handleCheckboxChange } from "../ducks/user_settings";

function mapStateToProps( ) {
  return { };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleCheckboxChange: newState => { dispatch( handleCheckboxChange( newState ) ); }
  };
}

const ToggleSwitchContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ToggleSwitch );

export default ToggleSwitchContainer;
