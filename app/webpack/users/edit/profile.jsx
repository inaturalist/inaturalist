import React from "react";

const Profile = () => (
  <div id="SettingsContainer">
    <div id="SettingsItem">
      <text id="ProfileHeader">
        Profile Picture
      </text>
      <div id="row">
        <image />
        <div className="centered-column">
          <button className="blue-button" type="button">
            <text className="blue-button-text">Upload new photo</text>
          </button>
          <button className="gray-button" type="button">
            <text className="gray-button-text">Remove photo</text>
          </button>
        </div>
      </div>
    </div>
    <div>Username</div>
    <div>Email</div>
    <div>Change Password</div>
    <div>Display name</div>
    <div>Bio</div>
    <div>Badges</div>
  </div>
);

export default Profile;
