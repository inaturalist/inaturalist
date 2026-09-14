// True once the Google Maps "maps" library has actually loaded.
export function googleMapsIsLoaded( ) {
  return typeof ( google ) !== "undefined"
    && !!google.maps
    && typeof ( google.maps.Map ) === "function";
}

export default googleMapsIsLoaded;
