import { connect } from "react-redux";

import Profile from "../components/profile";
import {
  handleInputChange,
  handlePhotoUpload,
  onFileDrop,
  removePhoto,
  changePassword,
  resendConfirmation
} from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleInputChange: e => dispatch( handleInputChange( e ) ),
    handlePhotoUpload: e => dispatch( handlePhotoUpload( e ) ),
    onFileDrop: droppedFiles => dispatch( onFileDrop( droppedFiles ) ),
    removePhoto: ( ) => dispatch( removePhoto( ) ),
    changePassword: input => dispatch( changePassword( input ) ),
    resendConfirmation: input => dispatch( resendConfirmation( ) )
  };
}

const ProfileContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Profile );

export default ProfileContainer;
