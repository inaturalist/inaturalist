import { connect } from "react-redux";

import Profile from "../components/profile";
import { setUserData, handleInputChange } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setUserData: newState => { dispatch( setUserData( newState ) ); },
    handleInputChange: newState => { dispatch( handleInputChange( newState ) ); }
  };
}

const ProfileContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Profile );

export default ProfileContainer;
