import React, { createRef } from "react";
import PropTypes from "prop-types";

const emptyProfileImage = "https://www.inaturalist.org/attachment_defaults/users/icons/defaults/thumb.png";

const Profile = ( { profile, setUserData, uploadPhoto } ) => {
  const hiddenFileInput = createRef( null );

  const handleInputChange = e => {
    const updatedProfile = profile;
    updatedProfile[e.target.name] = e.target.value;
    setUserData( updatedProfile );
  };

  const handleClick = ( ) => {
    hiddenFileInput.current.click();
  };

  const handleChange = e => {
    const fileUploaded = e.target.files[0];
    const formData = new FormData( );
    formData.append( "icon", fileUploaded.name );
    // console.log( fileUploaded, "file uploaded", formData );
    // uploadPhoto( formData );
  };

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "profile_picture" )}</h5>
            <div className="row row-align-center">
              <div className="col-xs-4">
                <img alt="profile-empty" src={profile.icon || emptyProfileImage} className="user-photo" />
              </div>
              <div className="col-xs-3 centered-column">
                <button
                  className="btn btn-xs btn-primary"
                  type="button"
                  onClick={handleClick}
                >
                  {I18n.t( "upload_new_photo" )}
                </button>
                <input className="hidden-input" type="file" ref={hiddenFileInput} onChange={handleChange} accept="image/*" />
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
              <input type="text" className="form-control" value={profile.login} name="login" onChange={handleInputChange} />
            </div>
          </div>
          <div className="profile-setting">
            <h5>
              {I18n.t( "email" )}
              <div className="asterisk">*</div>
            </h5>
            <div className="italic-text">{I18n.t( "email_description" )}</div>
            <input type="text" className="form-control" value={profile.email} name="email" onChange={handleInputChange} />
          </div>
          <div className="profile-setting">
            <h5>
              {I18n.t( "change_password" )}
              <div className="downward-caret">&#x25BE;</div>
            </h5>
            <form className="margin-medium-small">
              <label>{I18n.t( "new_password" )}</label>
              <input type="text" className="form-control" name="new_password" />
            </form>
            <form className="margin-medium">
              <label>{I18n.t( "confirm_new_password" )}</label>
              <input type="text" className="form-control" name="confirm_new_password" />
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
              <input type="text" className="form-control" value={profile.name} name="name" onChange={handleInputChange} />
            </div>
          </div>
          <div className="profile-setting">
            <h5>
              {I18n.t( "bio" )}
              <div className="asterisk">*</div>
            </h5>
            <div className="italic-text">{I18n.t( "bio_description" )}</div>
            <textarea className="form-control" value={profile ? profile.description : ""} name="description" onChange={handleInputChange} />
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "badges" )}</h5>
            <div className="row">
              <div className="col-xs-1">
                <input
                  type="checkbox"
                  className="form-check-input"
                  value={profile ? profile.prefers_monthly_supporters_badge : ""}
                  name="prefers_monthly_supporter_badge"
                  onChange={handleInputChange}
                />
              </div>
              <div className="col-xs-9">
                <label>{I18n.t( "display_monthly_supporter_badge" )}</label>
                <div className="italic-text">{I18n.t( "display_monthly_supporter_badge_description" )}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

Profile.propTypes = {
  profile: PropTypes.object,
  setUserData: PropTypes.func
};

export default Profile;
