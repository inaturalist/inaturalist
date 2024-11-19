import inatjs from "inaturalistjs";
import { parseRailsErrorsResponse } from "../../../shared/util";

import { fetchUserSettings } from "./user_settings";

export function addTaxonNamePriority( lexicon, placeID ) {
  return dispatch => {
    const payload = {
      taxon_name_priority: {
        lexicon,
        place_id: placeID
      }
    };
    return inatjs.taxon_name_priorities.create( payload ).then( ( ) => {
      dispatch( fetchUserSettings( ) );
    } ).catch( e => {
      e.response.text( ).then( text => {
        const railsErrors = parseRailsErrorsResponse( text );
        const message = `Failed to create taxon name priority: ${railsErrors.join( ", " )}`;
        alert( message );
      } ).catch( ( ) => {
        const message = `Failed to create taxon name priority: ${e}`;
        alert( message );
      } );
    } );
  };
}

export function deleteTaxonNamePriority( TaxonNamePriorityID ) {
  return dispatch => (
    inatjs.taxon_name_priorities.delete( { id: TaxonNamePriorityID } ).then( ( ) => {
      dispatch( fetchUserSettings( ) );
    } ).catch( e => {
      e.response.text( ).then( text => {
        const railsErrors = parseRailsErrorsResponse( text );
        const message = `Failed to create taxon name priority: ${railsErrors.join( ", " )}`;
        alert( message );
      } ).catch( ( ) => {
        const message = `Failed to create taxon name priority: ${e}`;
        alert( message );
      } );
    } )
  );
}

export function updateTaxonNamePriority( TaxonNamePriorityID, newPosition ) {
  return dispatch => {
    const payload = {
      id: TaxonNamePriorityID,
      taxon_name_priority: {
        position: newPosition
      }
    };
    inatjs.taxon_name_priorities.update( payload ).then( ( ) => {
      dispatch( fetchUserSettings( ) );
    } ).catch( e => {
      e.response.text( ).then( text => {
        const railsErrors = parseRailsErrorsResponse( text );
        const message = `Failed to create taxon name priority: ${railsErrors.join( ", " )}`;
        alert( message );
      } ).catch( ( ) => {
        const message = `Failed to create taxon name priority: ${e}`;
        alert( message );
      } );
    } );
  };
}
