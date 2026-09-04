// Exposes the notification-count setters to the legacy Sprockets bundle, whose
// dropdown handlers still reset them imperatively. Initial counts arrive as data
// attributes on #header (see initHeaderCounts), not an inline layout script.
import debounce from "lodash/debounce";
import {
  fitHeader,
  initHeaderCounts,
  setMessagesCount,
  setUpdatesCount
} from "./header";

// TODO: drop this window bridge once application.js.erb's notification dropdown
// handlers (which call setUpdatesCount/setMessagesCount to reset the badge on
// open) are migrated into webpack and can import these directly.
Object.assign( window, { setMessagesCount, setUpdatesCount } );

function start( ): void {
  if ( !document.getElementById( "header" ) ) { return; }

  fitHeader( );
  $( window ).on( "resize", debounce( fitHeader, 100 ) );
  initHeaderCounts( );
}

if ( document.readyState === "loading" ) {
  document.addEventListener( "DOMContentLoaded", start );
} else {
  start( );
}
