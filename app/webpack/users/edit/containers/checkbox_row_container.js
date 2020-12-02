import { connect } from "react-redux";

import CheckboxRow from "../components/checkbox_row";
import { handleCheckboxChange } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleCheckboxChange: newState => { dispatch( handleCheckboxChange( newState ) ); },
  };
}

const CheckboxRowContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CheckboxRow );

export default CheckboxRowContainer;
