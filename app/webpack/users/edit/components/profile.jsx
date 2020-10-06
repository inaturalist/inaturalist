import React from "react";
import PropTypes from "prop-types";

// import UserImage from "../../../shared/components/user_image";

const emptyProfileImage = "https://www.inaturalist.org/attachment_defaults/users/icons/defaults/thumb.png";

const Profile = ( { profile } ) => (
  <div className="col-xs-9">
    <div className="row">
      <div className="col-md-4 col-xs-10">
        <div className="profile-setting">
          <h5>{I18n.t( "profile_picture" )}</h5>
          <div className="row row-align-center">
            {/* <UserImage user={currentUser} /> */}
            <img alt="profile-empty" src={emptyProfileImage} className="user-photo" />
            <div className="centered-column">
              <button className="btn btn-xs btn-primary" type="button">
                {I18n.t( "upload_new_photo" )}
              </button>
              <button className="btn gray-button" type="button">
                <div className="gray-button-text">{I18n.t( "remove_photo" )}</div>
              </button>
            </div>
          </div>
        </div>
        <div className="profile-setting">
          <h5>
            {I18n.t( "username" )}
            <div className="asterisk">*</div>
          </h5>
          <div className="italic-text">{I18n.t( "username_description" )}</div>
          <div className="input-group">
            <input type="text" className="form-control" value={profile.login} />
          </div>
        </div>
        <div className="profile-setting">
          <h5>
            {I18n.t( "email" )}
            <div className="asterisk">*</div>
          </h5>
          <div className="italic-text">{I18n.t( "email_description" )}</div>
          <form><input type="text" className="form-control" value={profile ? profile.email : ""} /></form>
        </div>
        <div className="profile-setting">
          <h5>
            {I18n.t( "change_password" )}
            <div className="downward-caret">&#x25BE;</div>
          </h5>
          <form className="margin-medium-small">
            <label className="label">{I18n.t( "new_password" )}</label>
            <input type="text" className="form-control" />
          </form>
          <form className="margin-medium">
            <label className="label">{I18n.t( "confirm_new_password" )}</label>
            <input type="text" className="form-control" />
          </form>
          <button className="btn btn-xs btn-primary" type="button">
            {I18n.t( "change_password" )}
          </button>
        </div>
      </div>
      <div className="col-md-1" />
      <div className="col-md-6 col-xs-10">
        <div className="profile-setting">
          <h5>
            {I18n.t( "display_name" )}
            <div className="asterisk">*</div>
          </h5>
          <div className="italic-text">{I18n.t( "display_name_description" )}</div>
          <div className="input-group">
            <input type="text" className="form-control" value={profile ? profile.name : ""} />
          </div>
        </div>
        <div className="profile-setting">
          <h5>
            {I18n.t( "bio" )}
            <div className="asterisk">*</div>
          </h5>
          <div className="italic-text">{I18n.t( "bio_description" )}</div>
          <textarea className="form-control" value={profile ? profile.description : ""} />
        </div>
        <div className="profile-setting">
          <h5>{I18n.t( "badges" )}</h5>
          <div className="row save-button">
            <div className="col">
              <input type="checkbox" className="form-check-input" />
            </div>
            <div className="col">
              <h5 className="small">{I18n.t( "display_monthly_supporter_badge" )}</h5>
              <div className="italic-text">{I18n.t( "display_monthly_supporter_badge_description" )}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
);

Profile.propTypes = {
  profile: PropTypes.object
};

export default Profile;
