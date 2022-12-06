import inatjs from "inaturalistjs";

import { fetchUserSettings } from "./user_settings";

export function addTaxonNamePreference( lexicon, placeID ) {
  return dispatch => {
    const payload = {
      taxon_name_preference: {
        lexicon,
        place_id: placeID
      }
    };
    return inatjs.taxon_name_preferences.create( payload ).then( ( ) => {
      dispatch( fetchUserSettings( ) );
    } ).catch( e => console.log( `Failed to create taxon name preference: ${e}` ) );
  };
}

export function deleteTaxonNamePreference( taxonNamePreferenceID ) {
  return dispatch => (
    inatjs.taxon_name_preferences.delete( { id: taxonNamePreferenceID } ).then( ( ) => {
      dispatch( fetchUserSettings( ) );
    } ).catch( e => console.log( `Failed to delete taxon name preference: ${e}` ) )
  );
}
