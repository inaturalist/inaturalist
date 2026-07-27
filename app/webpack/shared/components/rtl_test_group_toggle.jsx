import React from "react";
import PropTypes from "prop-types";
import TestGroupToggle from "./test_group_toggle";

// Exported so the legacy variant can gate on the same rule instead of keeping a
// second copy of it in sync.
export const rtlTestGroupToggleVisible = config => {
  if ( !config || !config.currentUser ) return false;
  return config.currentUser.roles.indexOf( "curator" ) >= 0
    || config.currentUser.roles.indexOf( "admin" ) >= 0
    || ["ar", "fa", "he"].indexOf( config.currentUser.locale ) >= 0;
};

const RtlTestGroupToggle = ( { config } ) => {
  if ( !rtlTestGroupToggleVisible( config ) ) return null;
  return (
    <div className="container">
      <div className="row">
        <div className="cols-xs-12">
          <TestGroupToggle
            group="rtl"
            joinPrompt={I18n.t( "rtl_test_prompt" )}
            joinedStatus={I18n.t( "rtl_test_joined_status" )}
            user={config.currentUser}
          />
        </div>
      </div>
    </div>
  );
};

RtlTestGroupToggle.propTypes = {
  config: PropTypes.object
};

export default RtlTestGroupToggle;
