import React from "react";
import PropTypes from "prop-types";

const Account = ( { profile, setUserData } ) => {
  const handleInputChange = e => {
    const updatedProfile = profile;
    updatedProfile[e.target.name] = e.target.value;
    setUserData( updatedProfile );
  };

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          account column 1
        </div>
        <div className="col-md-1" />
        <div className="col-md-6 col-xs-10">
          account column 2
        </div>
      </div>
    </div>
  );
};

Account.propTypes = {
  profile: PropTypes.object,
  setUserData: PropTypes.func
};

export default Account;
