import React from "react";

const DonateNeedsSupport = ( ) => (
  <>
    <h3>
      <a name="donate" href="#donate">
        <span>{I18n.t( "yir_donate_inaturalist_needs_your_support" )}</span>
      </a>
    </h3>
    <div className="flex-row">
      <div className="donate-image" />
      <div>
        <ul>
          <li><p>{ I18n.t( "yir_millions_of_people_used_inaturalist" ) }</p></li>
          <li><p>{ I18n.t( "yir_generating_and_sharing" ) }</p></li>
          <li><p>{ I18n.t( "yir_your_gift_sustains" ) }</p></li>
        </ul>
      </div>
    </div>
  </>
);

export default DonateNeedsSupport;
