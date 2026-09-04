// Exposes the header behavior to the layouts, which call the count setters from
// an inline script, and to the legacy Sprockets bundle, which calls them from
// the notification dropdown handlers.
import debounce from "lodash/debounce";
import {
  fitHeader,
  getHeaderCounts,
  getMessagesCount,
  getUpdatesCount,
  setMessagesCount,
  setUpdatesCount
} from "./header";

Object.assign( window, {
  fitHeader,
  getHeaderCounts,
  getMessagesCount,
  getUpdatesCount,
  setMessagesCount,
  setUpdatesCount
} );

function start( ): void {
  if ( !document.getElementById( "header" ) ) { return; }

  fitHeader( );
  $( window ).on( "resize", debounce( fitHeader, 100 ) );
}

if ( document.readyState === "loading" ) {
  document.addEventListener( "DOMContentLoaded", start );
} else {
  start( );
}
