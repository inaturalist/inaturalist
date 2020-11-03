import React from "react";
import PropTypes from "prop-types";

import SettingsItem from "./settings_item";
import UserFollowing from "./user_following";

const BlockedMutedUsers = ( {
  sampleData,
  headerText,
  id,
  placeholder,
  buttonText,
  htmlDescription
} ) => (
  <div className="col-md-6">
    <SettingsItem header={headerText} htmlFor={id}>
      <div className="input-group">
        <input
          id={id}
          type="text"
          className="form-control"
          name={id}
          placeholder={placeholder}
        />
      </div>
      {sampleData.map( user => (
        <div className="row flex-no-wrap" key={user.name}>
          <div className="col-sm-9">
            <UserFollowing user={user} />
          </div>
          <div className="col-sm-3">
            <button type="button" className="btn btn-default btn-xs">
              {buttonText}
            </button>
          </div>
        </div>
      ) )}
    </SettingsItem>
    <p
      className="text-muted"
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={htmlDescription}
    />
  </div>
);

BlockedMutedUsers.propTypes = {
  sampleData: PropTypes.array,
  headerText: PropTypes.string,
  id: PropTypes.string,
  placeholder: PropTypes.string,
  buttonText: PropTypes.string,
  htmlDescription: PropTypes.object
};

export default BlockedMutedUsers;
