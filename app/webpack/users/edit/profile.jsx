import React from "react";

const emptyProfileImage = "https://www.inaturalist.org/attachment_defaults/users/icons/defaults/thumb.png"

const Profile = () => (
  <div id="SettingsContainer">
    <div id="SettingsItem">
      <text id="ProfileHeader">
        {I18n.t( "profile_picture" )}
      </text>
      <div id="row">
        <img alt="profile-empty" src={emptyProfileImage} />
        <div className="centered-column">
          <button className="blue-button" type="button">
            <text className="blue-button-text">{I18n.t( "upload_new_photo" )}</text>
          </button>
          <button className="gray-button" type="button">
            <text className="gray-button-text">{I18n.t( "remove_photo" )}</text>
          </button>
        </div>
      </div>
    </div>
    <div>{I18n.t( "username" )}</div>
    <div>{I18n.t( "email" )}</div>
    <div>{I18n.t( "change_password" )}</div>
    <div>{I18n.t( "display_name" )}</div>
    <div>{I18n.t( "bio" )}</div>
    <div>{I18n.t( "badges" )}</div>
  </div>
);

export default Profile;
