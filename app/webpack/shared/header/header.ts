interface CountOptions {
  skipAnimation?: boolean;
}

const MAX_HEADER_COUNT = 999;
const MAX_NARROW_HEADER_COUNT = 99;

const headerCounts = { updates: 0, messages: 0 };

// The badge width is what keeps the header inside narrow viewports
export function formatHeaderCount( count: number ): string {
  return count > MAX_HEADER_COUNT ? `${MAX_HEADER_COUNT}+` : String( count );
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

  $( `${selector} .count` ).html( formatHeaderCount( count ) );

  headerCounts[nav] = count;
  document.getElementById( "header" )?.classList.toggle(
    "long-counts",
    headerCounts.updates > MAX_NARROW_HEADER_COUNT
      || headerCounts.messages > MAX_NARROW_HEADER_COUNT
  );
}

export function setUpdatesCount( count: number, options: CountOptions = {} ): void {
  setHeaderCount( "updates", count, options );
}

export function setMessagesCount( count: number, options: CountOptions = {} ): void {
  setHeaderCount( "messages", count, options );
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

export function readHeaderCounts( ): { updates: number; messages: number } | null {
  const header = document.getElementById( "header" );
  const updates = header?.dataset.updatesCount;
  const messages = header?.dataset.messagesCount;
  if ( updates === undefined || messages === undefined ) { return null; }

  return { updates: Number( updates ), messages: Number( messages ) };
}

export function initHeaderCounts( ): void {
  const counts = readHeaderCounts( );
  if ( !counts ) { return; }

  setUpdatesCount( counts.updates, { skipAnimation: true } );
  setMessagesCount( counts.messages, { skipAnimation: true } );
  window.setTimeout( getHeaderCounts, 1000 );
}
