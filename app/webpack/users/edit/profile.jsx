import React from "react";

const emptyProfileImage = "https://www.inaturalist.org/attachment_defaults/users/icons/defaults/thumb.png"

const Profile = () => (
  <div id="SettingsContainer" className="two-column">
    <div id="SettingsItem">
      <div id="Header">{I18n.t( "profile_picture" )}</div>
      <div id="Row" className="profile-picture">
        <img alt="profile-empty" src={emptyProfileImage} className="user-photo" />
        <div className="centered-column">
          <button className="blue-button" type="button">
            <div className="blue-button-text">{I18n.t( "upload_new_photo" )}</div>
          </button>
          <button className="gray-button" type="button">
            <div className="gray-button-text">{I18n.t( "remove_photo" )}</div>
          </button>
        </div>
      </div>
    </div>
    <div id="SettingsItem">
      <div id="Header">
        {I18n.t( "username" )}
        <div className="asterisk">*</div>
      </div>
      <div className="italic-text">{I18n.t( "username_description" )}</div>
      <form><input type="text" id="InputSmall" /></form>
    </div>
    <div id="SettingsItem">
      <div id="Header">
        {I18n.t( "email" )}
        <div className="asterisk">*</div>
      </div>
      <div className="italic-text">{I18n.t( "email_description" )}</div>
      <form><input type="text" id="InputMedium" /></form>
    </div>
    <div id="SettingsItem">
      <div id="Header" className="margin-medium">{I18n.t( "change_password" )}</div>
      <div id="Header" className="small">{I18n.t( "new_password" )}</div>
      <form className="margin-medium-small"><input type="text" id="InputMedium" /></form>
      <div id="Header" className="small">{I18n.t( "confirm_new_password" )}</div>
      <form className="margin-medium"><input type="text" id="InputMedium" /></form>
      <button className="blue-button" type="button">
        <div className="blue-button-text">{I18n.t( "change_password" )}</div>
      </button>
    </div>
    <div id="SettingsItem">
      <div id="Header">
        {I18n.t( "display_name" )}
        <div className="asterisk">*</div>
      </div>
      <div className="italic-text">{I18n.t( "display_name_description" )}</div>
      <form><input type="text" id="InputSmall" /></form>
    </div>
    <div id="SettingsItem">
      <div id="Header">
        {I18n.t( "bio" )}
        <div className="asterisk">*</div>
      </div>
      <div className="italic-text">{I18n.t( "bio_description" )}</div>
      <form><input type="text" id="InputLarge" /></form>
    </div>
    <div id="SettingsItem">
      <div id="Header" className="margin-medium">{I18n.t( "badges" )}</div>
      <form id="Row">
        <input type="checkbox" id="Checkbox" />
        <div id="Column">
          <div id="Header" className="small">{I18n.t( "display_monthly_supporter_badge" )}</div>
          <div className="italic-text">{I18n.t( "display_monthly_supporter_badge_description" )}</div>
        </div>
      </form>
    </div>
  </div>
);

export default Profile;
