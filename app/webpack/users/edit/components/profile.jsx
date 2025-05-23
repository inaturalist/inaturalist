import _ from "lodash";
import React, { createRef } from "react";
import PropTypes from "prop-types";
import Dropzone from "react-dropzone";
import moment from "moment";

import CheckboxRowContainer from "../containers/checkbox_row_container";
import SettingsItem from "./settings_item";
import ChangePasswordContainer from "../containers/change_password_container";
import UserImage from "../../../shared/components/user_image";
import UserError from "./user_error";
import { MAX_FILE_SIZE } from "../../../observations/uploader/models/util";

const DESCRIPTION_WARNING_LENGTH = 8000;
const MAX_DESCRIPTION_LENGTH = 10000;

const Profile = ( {
  handleInputChange,
  handlePhotoUpload,
  onFileDrop,
  removePhoto,
  confirmResendConfirmation,
  resendConfirmation,
  userSettings
} ) => {
  const hiddenFileInput = createRef( null );
  const iconDropzone = createRef( );
  const descriptionLength = ( userSettings.description || "" ).length;

  const showFileDialog = ( ) => iconDropzone.current.open( );

  const showUserIcon = ( ) => {
    if ( userSettings.icon && userSettings.icon.preview ) {
      return (
        <a
          className="userimage UserImage"
          href={`/people/${userSettings.login || userSettings.id}`}
          title={userSettings.login}
          label={I18n.t( "profile_picture" )}
          style={{ backgroundImage: `url("${userSettings.icon.preview}")` }}
        />
      );
    }
    return <UserImage user={userSettings} />;
  };

  // this gets rid of the React warning about inputs being controlled vs. uncontrolled
  // by ensuring user data is fetched before the Profile & User page loads
  if ( _.isEmpty( userSettings ) ) {
    return null;
  }

  const unconfirmedEmailAlert = (
    <div className="alert alert-warning alert-mini">
      <span
        dangerouslySetInnerHTML={{
          __html: I18n.t( "change_to_email_requested_html", { email: userSettings.unconfirmed_email } )
        }}
      />
      { " " }
      <button
        type="button"
        className="btn btn-nostyle alert-link"
        onClick={( ) => resendConfirmation( )}
      >
        { I18n.t( "resend_confirmation_email" ) }
      </button>
    </div>
  );

  let emailConfirmation = (
    <div>
      <p className="text-success">
        { I18n.t( "confirmed_on_date", {
          date: moment( userSettings.confirmed_at ).format( I18n.t( "momentjs.date_long" ) )
        } )}
      </p>
      { userSettings.unconfirmed_email && unconfirmedEmailAlert }
    </div>
  );
  if ( !userSettings.confirmed_at && userSettings.unconfirmed_email ) {
    emailConfirmation = unconfirmedEmailAlert;
  } else if ( !userSettings.confirmed_at ) {
    emailConfirmation = (
      <div
        className={`alert alert-mini alert-${userSettings.confirmation_sent_at ? "warning" : "danger"}`}
      >
        {
          userSettings.confirmation_sent_at
            ? I18n.t( "confirmation_email_sent_at_datetime", {
              datetime: moment( userSettings.confirmation_sent_at ).format( I18n.t( "momentjs.datetime_with_zone_no_year" ) )
            } )
            : I18n.t( "you_have_not_confirmed_your_email_address" )
        }
        { " " }
        <button
          type="button"
          className="btn btn-nostyle alert-link"
          onClick={( ) => confirmResendConfirmation( )}
        >
          {
            userSettings.confirmation_sent_at
              ? I18n.t( "resend_confirmation_email" )
              : I18n.t( "send_confirmation_email", {
                defaultValue: I18n.t( "resend_confirmation_email" )
              } )
          }
        </button>
      </div>
    );
  }

  return (
    <div className="row">
      <div className="col-md-5 col-sm-10">
        <h4>{I18n.t( "profile" )}</h4>
        <SettingsItem header={I18n.t( "profile_picture" )} htmlFor="user_icon">
          <UserError user={userSettings} attribute="icon_content_type" alias="profile_picture_file_type" />
          <Dropzone
            ref={iconDropzone}
            className="dropzone"
            onDrop={( acceptedFiles, rejectedFiles, dropEvent ) => {
              // trying to protect against treating images dragged from the
              // same page from being treated as new files. Images dragged from
              // the same page will appear as multiple dataTransferItems, the
              // first being a "string" kind and not a "file" kind
              if ( dropEvent.nativeEvent.dataTransfer
                && dropEvent.nativeEvent.dataTransfer.items
                && dropEvent.nativeEvent.dataTransfer.items.length > 0
                && dropEvent.nativeEvent.dataTransfer.items[0].kind === "string" ) {
                return;
              }
              _.each( acceptedFiles, file => {
                try {
                  file.preview = file.preview || window.URL.createObjectURL( file );
                } catch ( err ) {
                  // eslint-disable-next-line no-console
                  console.error( "Failed to generate preview for file", file, err );
                }
              } );
              onFileDrop( acceptedFiles, rejectedFiles );
            }}
            activeClassName="hover"
            disableClick
            disablePreview
            accept="image/png,image/jpeg,image/gif"
            multiple={false}
            maxSize={MAX_FILE_SIZE}
          >
            <div className="flex-no-wrap">
              <div className="user-profile-image">
                {showUserIcon( )}
              </div>
              <div className="add-remove-user-photo">
                <button
                  className="btn btn-primary"
                  type="button"
                  onClick={showFileDialog}
                >
                  {I18n.t( "upload_new_photo" )}
                </button>
                <input
                  id="user_icon"
                  className="hide"
                  value=""
                  type="file"
                  ref={hiddenFileInput}
                  onChange={handlePhotoUpload}
                  accept="image/*"
                />
                <button className="btn btn-default remove-photo-margin" type="button" onClick={removePhoto}>
                  {I18n.t( "remove_photo" )}
                </button>
              </div>
            </div>
          </Dropzone>
        </SettingsItem>
        <SettingsItem header={I18n.t( "username" )} required htmlFor="user_login">
          <div className="text-muted help-text">{I18n.t( "username_description" )}</div>
          <UserError user={userSettings} attribute="login" alias="username" />
          <input
            id="user_login"
            type="text"
            className="form-control"
            value={userSettings.login}
            name="login"
            onChange={handleInputChange}
          />
        </SettingsItem>
        <SettingsItem header={I18n.t( "email" )} required htmlFor="user_email">
          <div className="text-muted help-text">{I18n.t( "email_description" )}</div>
          <UserError user={userSettings} attribute="email" />
          <input
            id="user_email"
            type="text"
            className="form-control"
            value={userSettings.email || ""}
            name="email"
            onChange={handleInputChange}
          />
          { emailConfirmation }
        </SettingsItem>
        <ChangePasswordContainer user={userSettings} />
      </div>
      <div className="col-md-offset-1 col-md-6 col-sm-10">
        <SettingsItem header={I18n.t( "display_name" )} htmlFor="user_name">
          <div className="text-muted help-text">{I18n.t( "display_name_description" )}</div>
          <UserError user={userSettings} attribute="name" />
          <input
            id="user_name"
            type="text"
            className="form-control"
            value={userSettings.name || ""}
            name="name"
            onChange={handleInputChange}
          />
        </SettingsItem>
        <SettingsItem header={I18n.t( "bio" )} htmlFor="user_description">
          <div className="text-muted help-text">{I18n.t( "bio_description" )}</div>
          <UserError user={userSettings} attribute="description" />
          <textarea
            id="user_description"
            className="form-control user-description"
            value={userSettings.description || ""}
            name="description"
            onChange={handleInputChange}
          />
          {
            descriptionLength > DESCRIPTION_WARNING_LENGTH && (
              <div className="text-muted small chars-remaining">
                { I18n.t( "x_of_y_short", { x: descriptionLength, y: MAX_DESCRIPTION_LENGTH } )}
              </div>
            )
          }
        </SettingsItem>
        <SettingsItem header={I18n.t( "badges" )} htmlFor="user_prefers_monthly_supporter_badge">
          <CheckboxRowContainer
            name="prefers_monthly_supporter_badge"
            label={I18n.t( "display_monthly_supporter_badge" )}
            description={
              I18n.t( "views.users.edit.monthly_supporter_desc_html", {
                url: "https://www.inaturalist.org/monthly-supporters?utm_campaign=monthly-supporter&utm_content=inline-link&utm_medium=web&utm_source=inaturalist.org&utm_term=account-settings"
              } )
            }
            disabled={!userSettings.monthly_supporter}
          />
        </SettingsItem>
      </div>
    </div>
  );
};

Profile.propTypes = {
  confirmResendConfirmation: PropTypes.func,
  handleInputChange: PropTypes.func,
  handlePhotoUpload: PropTypes.func,
  onFileDrop: PropTypes.func,
  removePhoto: PropTypes.func,
  resendConfirmation: PropTypes.func,
  userSettings: PropTypes.object
};

export default Profile;
