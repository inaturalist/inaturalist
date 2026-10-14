import initDetailsMenu from "./details_menu";

function start( ): void {
  document.querySelectorAll<HTMLDetailsElement>( "details[data-details-menu]" ).forEach( initDetailsMenu );
}

if ( document.readyState === "loading" ) {
  document.addEventListener( "DOMContentLoaded", start );
} else {
  start( );
}
