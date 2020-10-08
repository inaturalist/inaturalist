import { connect } from "react-redux";

import Profile from "../components/profile";
import { setUserData, uploadPhoto } from "../ducks/profile";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setUserData: newState => { dispatch( setUserData( newState ) ); },
    uploadPhoto: newState => { dispatch( uploadPhoto( newState ) ); }
  };
}

const ProfileContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Profile );

export default ProfileContainer;
