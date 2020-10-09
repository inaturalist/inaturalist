import { connect } from "react-redux";

import Profile from "../components/profile";
import { setUserData } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setUserData: newState => { dispatch( setUserData( newState ) ); }
  };
}

const ProfileContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Profile );

export default ProfileContainer;
