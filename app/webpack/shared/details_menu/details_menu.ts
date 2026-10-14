export default function initDetailsMenu( details: HTMLDetailsElement ): void {
  document.addEventListener( "click", e => {
    if ( details.open && !details.contains( e.target as Node ) ) {
      details.open = false;
    }
  } );
  details.addEventListener( "keydown", e => {
    if ( e.key !== "Escape" ) { return; }
    details.open = false;
    details.querySelector( "summary" )?.focus( );
  } );
}
