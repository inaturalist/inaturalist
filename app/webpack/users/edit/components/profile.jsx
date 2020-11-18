import React, { createRef } from "react";
import PropTypes from "prop-types";
import Dropzone from "react-dropzone";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import ChangePassword from "./change_password";
import UserImage from "../../../shared/components/user_image";

const Profile = ( {
  profile,
  handleInputChange,
  handlePhotoUpload,
  onFileDrop,
  removePhoto,
  changePassword
} ) => {
  const hiddenFileInput = createRef( null );
  const iconDropzone = createRef( );

  const showFileDialog = ( ) => hiddenFileInput.current.click();

  const showPhotoPreview = icon => (
    <img
      alt="user-icon"
      src={icon}
      className="user-photo"
    />
  );

  const showUserIcon = ( ) => {
    if ( typeof profile.icon === "object" && profile.icon !== null ) {
      // preview means user dragged photo into dropzone;
      // icon means they clicked 'upload new photo' file dialog
      return showPhotoPreview( profile.icon.preview ? profile.icon.preview : profile.icon );
    }
    return <UserImage user={profile} />;
  };

  // this gets rid of the React warning about inputs being controlled vs. uncontrolled
  // by ensuring user data is fetched before the Profile & User page loads
  if ( !profile.login && !profile.email ) {
    return null;
  }

  return (
    <div className="row">
      <div className="col-md-5 col-sm-10">
        <SettingsItem header={I18n.t( "profile_picture" )} htmlFor="user_icon">
          <Dropzone
            ref={iconDropzone}
            className="dropzone"
            onDrop={droppedFiles => onFileDrop( droppedFiles )}
            activeClassName="hover"
            disableClick
            accept="image/png,image/jpeg,image/gif"
            multiple={false}
          >
            <div className="row profile-photo-margin">
              <div className="col-sm-4 user-profile-image">
                {showUserIcon( )}
              </div>
              <div className="col-sm-3 centered-column">
                <button
                  className="btn btn-xs btn-primary"
                  type="button"
                  onClick={showFileDialog}
                >
                  {I18n.t( "upload_new_photo" )}
                </button>
                <input id="user_icon" className="hide" type="file" ref={hiddenFileInput} onChange={handlePhotoUpload} accept="image/*" />
                <button className="btn btn-default btn-xs remove-photo-margin" type="button" onClick={removePhoto}>
                  {I18n.t( "remove_photo" )}
                </button>
              </div>
            </div>
          </Dropzone>
        </SettingsItem>
        <SettingsItem header={I18n.t( "username" )} required htmlFor="user_login">
          <div className="text-muted help-text">{I18n.t( "username_description" )}</div>
          <div className="input-group">
            <input id="user_login" type="text" className="form-control" value={profile.login} name="login" onChange={handleInputChange} />
          </div>
        </SettingsItem>
        <SettingsItem header={I18n.t( "email" )} required htmlFor="user_email">
          <div className="text-muted help-text">{I18n.t( "email_description" )}</div>
          <input id="user_email" type="text" className="form-control" value={profile.email} name="email" onChange={handleInputChange} />
        </SettingsItem>
        <ChangePassword changePassword={changePassword} />
      </div>
      <div className="col-md-1" />
      <div className="col-md-5 col-sm-10">
        <SettingsItem header={I18n.t( "display_name" )} required htmlFor="user_name">
          <div className="text-muted help-text">{I18n.t( "display_name_description" )}</div>
          <div className="input-group">
            <input id="user_name" type="text" className="form-control" value={profile.name} name="name" onChange={handleInputChange} />
          </div>
        </SettingsItem>
        <SettingsItem header={I18n.t( "bio" )} required htmlFor="user_description">
          <div className="text-muted help-text">{I18n.t( "bio_description" )}</div>
          <textarea id="user_description" className="form-control" value={profile.description} name="description" onChange={handleInputChange} />
        </SettingsItem>
        <SettingsItem header={I18n.t( "badges" )} htmlFor="user_prefers_monthly_supporter_badge">
          <CheckboxRowContainer
            name="prefers_monthly_supporter_badge"
            label={I18n.t( "display_monthly_supporter_badge" )}
            description={(
              <p
                className="text-muted"
                // eslint-disable-next-line react/no-danger
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.users.edit.monthly_supporter_desc_html", {
                    url: "https://www.inaturalist.org/monthly-supporters?utm_campaign=monthly-supporter&utm_content=inline-link&utm_medium=web&utm_source=inaturalist.org&utm_term=account-settings"
                  } )
                }}
              />
            )}
          />
        </SettingsItem>
      </div>
    </div>
  );
};

Profile.propTypes = {
  profile: PropTypes.object,
  handleInputChange: PropTypes.func,
  handlePhotoUpload: PropTypes.func,
  onFileDrop: PropTypes.func,
  removePhoto: PropTypes.func,
  changePassword: PropTypes.func
};

export default Profile;
