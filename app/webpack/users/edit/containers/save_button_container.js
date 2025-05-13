import { connect } from "react-redux";

import SaveButton from "../components/save_button";
import { postUserSettings } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    saveUserSettings: newState => { dispatch( postUserSettings( newState ) ); }
  };
}

const SaveButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SaveButton );

export default SaveButtonContainer;
