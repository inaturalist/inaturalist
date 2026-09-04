// Behavior for the site header rendered by app/views/shared/_header.html.haml.

interface CountOptions {
  skipAnimation?: boolean;
}

// Beyond this the exact number adds width without adding meaning, and the
// header has little width to spare on narrow screens.
const MAX_HEADER_COUNT = 99;

export function headerCountLabel( count: number ): string {
  return count > MAX_HEADER_COUNT ? `${MAX_HEADER_COUNT}+` : String( count );
}

// The header lays out in a single row, so long notification counts can push it
// wider than the viewport. Dropping the least essential item is preferable to
// horizontal overflow of the whole page.
export function fitHeader( ): void {
  const header = document.getElementById( "header" );
  if ( !header ) { return; }

  header.classList.remove( "crowded" );
  if ( header.scrollWidth > header.clientWidth ) {
    header.classList.add( "crowded" );
  }
}

function apiUrlV2( ): string {
  const meta = document.querySelector( "meta[name='config:inaturalist_api_url_v2']" );
  return meta?.getAttribute( "content" ) || "";
}

function apiToken( ): string {
  const meta = document.querySelector( "meta[name='inaturalist-api-token']" );
  return meta?.getAttribute( "content" ) || "";
}

function setHeaderCount(
  nav: "updates" | "messages",
  count: number,
  options: CountOptions = {}
): void {
  const selector = `#header .${nav}`;
  const hasCount = count > 0;

  if ( options.skipAnimation ) {
    $( selector )[hasCount ? "addClass" : "removeClass"]( "hasupdates" );
  } else {
    // switchClass animates the color change; addClass would snap to it.
    $( selector ).switchClass( hasCount ? "" : "hasupdates", hasCount ? "hasupdates" : "" );
  }

  $( `${selector} .count` ).html( hasCount ? headerCountLabel( count ) : "0" );
  fitHeader( );
}

export function setUpdatesCount( count: number, options: CountOptions = {} ): void {
  setHeaderCount( "updates", count, options );
}

export function setMessagesCount( count: number, options: CountOptions = {} ): void {
  setHeaderCount( "messages", count, options );
}

export function getUpdatesCount( ): void {
  $.getJSON( "/users/updates_count.json", ( data: { count: number } ) => {
    setUpdatesCount( data.count );
  } );
}

export function getMessagesCount( ): void {
  $.getJSON( "/messages/count.json", ( data: { count: number } ) => {
    setMessagesCount( data.count );
  } );
}

export function getHeaderCounts( ): void {
  $.ajax( {
    url: `${apiUrlV2( )}/users/notification_counts`,
    headers: { Authorization: apiToken( ) },
    success: ( data: { updates_count: number; messages_count: number } ) => {
      setUpdatesCount( data.updates_count );
      setMessagesCount( data.messages_count );
    }
  } );
}
