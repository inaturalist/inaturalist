import React from "react";
import RtlTestGroupToggle, { rtlTestGroupToggleVisible } from "./rtl_test_group_toggle";

interface Config {
  currentUser?: {
    roles?: string[];
    locale?: string;
  };
}

/**
 * Legacy placement of the RTL test banner.
 *
 * The responsive layouts render the banner full-bleed, but the legacy layouts
 * expect it inside the Bootstrap grid. Keeping that as a separate component lets
 * app_legacy (and the not-yet-converted taxa/projects pages) keep their existing
 * alignment while app.tsx renders the unwrapped version.
 *
 * The gate is checked here as well as in the wrapped component so an ineligible
 * viewer gets nothing at all rather than a pair of empty grid divs, whose .row
 * negative margins would leave a stray gutter.
 */
const RtlTestGroupToggleLegacy = ( { config }: { config?: Config } ) => {
  if ( !rtlTestGroupToggleVisible( config ) ) return null;
  return (
    <div className="container">
      <div className="row">
        { /* Production renders "cols-xs-12" here, which matches no Bootstrap
             class, so the column's 15px padding never offsets .row's -15px
             margins and the banner bleeds past the container. Corrected to
             col-xs-12, so this sits 15px narrower than prod on each side. */ }
        <div className="col-xs-12">
          <RtlTestGroupToggle config={config} />
        </div>
      </div>
    </div>
  );
};

export default RtlTestGroupToggleLegacy;
