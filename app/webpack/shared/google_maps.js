// True once the Google Maps "maps" library has actually loaded. Pages using
// google_maps_async_js define window.google and google.maps.importLibrary
// before any library loads, without any network request, so `typeof google`
// alone cannot tell whether the browser blocked requests to Google.
export function googleMapsIsLoaded( ) {
  return typeof ( google ) !== "undefined"
    && !!google.maps
    && typeof ( google.maps.Map ) === "function";
}

export default googleMapsIsLoaded;
