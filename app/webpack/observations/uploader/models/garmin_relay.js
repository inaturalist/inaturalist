// Options for geotrack's Garmin client in the uploader. Garmin refuses CORS,
// so requests go through the Rails relay (GarminRelayController) with the
// session cookie and CSRF token.
export const GARMIN_RELAY_URL = "/garmin_relay";

export function garminRelayOptions( ) {
  const csrfToken = document.querySelector( "meta[name='csrf-token']" )?.getAttribute( "content" );
  return {
    baseUrl: GARMIN_RELAY_URL,
    fetch: ( url, init = {} ) => fetch( url, {
      ...init,
      credentials: "same-origin",
      headers: { ...init.headers, ...( csrfToken ? { "X-CSRF-Token": csrfToken } : {} ) }
    } )
  };
}
