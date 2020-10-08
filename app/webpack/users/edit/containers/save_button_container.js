import { connect } from "react-redux";

import SaveButton from "../components/save_button";
import { saveUserProfile } from "../ducks/profile";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    saveUserProfile: newState => { dispatch( saveUserProfile( newState ) ); }
  };
}

const SaveButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SaveButton );

export default SaveButtonContainer;
