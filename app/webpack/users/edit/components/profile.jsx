import React from "react";
import PropTypes from "prop-types";

// import UserImage from "../../../shared/components/user_image";

const emptyProfileImage = "https://www.inaturalist.org/attachment_defaults/users/icons/defaults/thumb.png";

const Profile = ( { profile } ) => (
  <div id="SettingsContainer" className="two-column">
    <div id="SettingsItem">
      <div id="Header">{I18n.t( "profile_picture" )}</div>
      <div id="Row" className="profile-picture">
        {/* <UserImage user={currentUser} /> */}
        <img alt="profile-empty" src={emptyProfileImage} className="user-photo" />
        <div className="centered-column">
          <button className="btn btn-xs btn-primary" type="button">
            {I18n.t( "upload_new_photo" )}
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
      <div className="input-group">
        <input type="text" className="form-control" value={profile.login} />
      </div>
    </div>
    <div id="SettingsItem">
      <div id="Header">
        {I18n.t( "email" )}
        <div className="asterisk">*</div>
      </div>
      <div className="italic-text">{I18n.t( "email_description" )}</div>
      <form><input type="text" className="form-control" value={profile ? profile.email : ""} /></form>
    </div>
    <div id="SettingsItem">
      <div id="Header" className="margin-medium">
        {I18n.t( "change_password" )}
        <div className="downward-caret">&#x25BE;</div>
      </div>
      <div id="Header" className="small">{I18n.t( "new_password" )}</div>
      <form className="margin-medium-small"><input type="text" className="form-control" /></form>
      <div id="Header" className="small">{I18n.t( "confirm_new_password" )}</div>
      <form className="margin-medium"><input type="text" className="form-control" /></form>
      <button className="btn btn-xs btn-primary" type="button">
        {I18n.t( "change_password" )}
      </button>
    </div>
    <div id="SettingsItem">
      <div id="Header">
        {I18n.t( "display_name" )}
        <div className="asterisk">*</div>
      </div>
      <div className="italic-text">{I18n.t( "display_name_description" )}</div>
      <div className="input-group">
        <input type="text" className="form-control" value={profile ? profile.name : ""} />
      </div>
    </div>
    <div id="SettingsItem">
      <div id="Header">
        {I18n.t( "bio" )}
        <div className="asterisk">*</div>
      </div>
      <div className="italic-text">{I18n.t( "bio_description" )}</div>
      <form>
        <textarea className="form-control" value={profile ? profile.description : ""} />
      </form>
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

Profile.propTypes = {
  profile: PropTypes.object
};

export default Profile;
