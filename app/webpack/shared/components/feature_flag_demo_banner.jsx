import React from "react";
import featureFlagEnabled from "../feature_flags";

// WEB-1074 demo. Gates nothing real; it exists so one flag toggle is visible on the public
// site through the client-side path, alongside the footer badge that the server renders from
// the same flag. Off by default, and meant to be enabled for named actors only. Delete this
// component with the rest of the demo once a real flag ships.
//
// The pattern worth copying is the shape, not the content: read the flag, return null when it
// is off, and let the server decide who is in. See app/webpack/shared/feature_flags.js.
const FeatureFlagDemoBanner = ( ) => {
  if ( !featureFlagEnabled( "demo_banner" ) ) {
    return null;
  }
  return (
    <div className="container">
      <div className="row">
        <div className="col-xs-12">
          <div className="FeatureFlagDemoBanner alert alert-info text-center">
            { I18n.t( "feature_flag_demo_banner" ) }
          </div>
        </div>
      </div>
    </div>
  );
};

export default FeatureFlagDemoBanner;
