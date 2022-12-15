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
    } ).catch( e => {
      const message = `Failed to create taxon name preference: ${e}`;
      console.log( message );
      alert( message );
    } );
  };
}

export function deleteTaxonNamePreference( taxonNamePreferenceID ) {
  return dispatch => (
    inatjs.taxon_name_preferences.delete( { id: taxonNamePreferenceID } ).then( ( ) => {
      dispatch( fetchUserSettings( ) );
    } ).catch( e => {
      const message = `Failed to delete taxon name preference: ${e}`;
      console.log( message );
      alert( message );
    } )
  );
}

export function updateTaxonNamePreference( taxonNamePreferenceID, newPosition ) {
  return dispatch => {
    const payload = {
      id: taxonNamePreferenceID,
      taxon_name_preference: {
        position: newPosition
      }
    };
    inatjs.taxon_name_preferences.update( payload ).then( ( ) => {
      dispatch( fetchUserSettings( ) );
    } ).catch( e => {
      const message = `Failed to update taxon name preference: ${e}`;
      console.log( message );
      alert( message );
    } );
  };
}
