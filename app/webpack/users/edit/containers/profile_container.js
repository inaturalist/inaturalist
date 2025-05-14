import { connect } from "react-redux";

import Profile from "../components/profile";
import {
  handleInputChange,
  handlePhotoUpload,
  onFileDrop,
  removePhoto,
  changePassword,
  confirmResendConfirmation,
  resendConfirmation
} from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    userSettings: state.userSettings
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleInputChange: e => dispatch( handleInputChange( e ) ),
    handlePhotoUpload: e => dispatch( handlePhotoUpload( e ) ),
    onFileDrop: ( droppedFiles, rejectedFiles ) => (
      dispatch( onFileDrop( droppedFiles, rejectedFiles ) )
    ),
    removePhoto: ( ) => dispatch( removePhoto( ) ),
    changePassword: input => dispatch( changePassword( input ) ),
    resendConfirmation: ( ) => dispatch( resendConfirmation( ) ),
    confirmResendConfirmation: ( ) => dispatch( confirmResendConfirmation( ) )
  };
}

const ProfileContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Profile );

export default ProfileContainer;
