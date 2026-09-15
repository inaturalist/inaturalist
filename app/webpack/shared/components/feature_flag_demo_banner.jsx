import React from "react";
import featureFlagEnabled from "../feature_flags";

// Check flag at runtime; return null when off and let server gate enrollment.
const FeatureFlagDemoBanner = ( ) => {
  if ( !featureFlagEnabled( "client_demo_banner" ) ) {
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
