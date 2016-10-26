import React, { PropTypes } from "react";
import { Button } from "react-bootstrap";
import safeHtml from "safe-html";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import INatTextArea from "./inat_text_area";

const IdentificationForm = ( {
  observation: o,
  onSubmitIdentification,
  className,
  currentUser
} ) => (
  <form
    className={`IdentificationForm ${className}`}
    onSubmit={function ( e ) {
      e.preventDefault();
      const idTaxon = $( ".IdentificationForm:visible:first input[name='taxon_name']" ).
        data( "uiAutocomplete" ).selectedItem;
      if ( !idTaxon ) {
        return;
      }
      let confirmationText = safeHtml( I18n.t( "your_coarser_id", {
        coarser_taxon_name: idTaxon.name,
        finer_taxon_name: o.taxon ? o.taxon.name : ""
      } ), {} );
      confirmationText = confirmationText.replace( /<a.+?\/a>/, "" );
      confirmationText = confirmationText.replace( /<br>/g, "" );
      confirmationText = confirmationText.replace( /\s+/g, " " );
      const isDisagreement = ( ) => {
        if ( !o || !o.taxon || !o.taxon.rank_level || !o.taxon.rank_level ) {
          return false;
        }
        return ( idTaxon && idTaxon.rank_level > o.taxon.rank_level );
      };
      const currentUserSkippedConfirmation = (
        false && // test to see if this bugs people, we get a lot of mistaken coarse IDs
        currentUser &&
        currentUser.prefers_skip_coarer_id_modal
      );
      onSubmitIdentification( {
        observation_id: o.id,
        taxon_id: e.target.elements.taxon_id.value,
        body: e.target.elements.body.value
      }, {
        confirmationText: (
          ( isDisagreement( ) && !currentUserSkippedConfirmation ) ? confirmationText : null
        )
      } );
      // this doesn't feel right... somehow submitting an ID should alter
      // the app state and this stuff should flow three here as props
      $( "input[name='taxon_name']", e.target ).trigger( "resetAll" );
      $( e.target.elements.body ).val( null );
    }}
  >
    <h3>{ I18n.t( "add_an_identification" ) }</h3>
    <TaxonAutocomplete />
    <INatTextArea type="textarea" name="body" className="form-control" mentions />
    <Button type="submit" bsStyle="success">{ I18n.t( "save" ) }</Button>
  </form>
);

IdentificationForm.propTypes = {
  observation: PropTypes.object,
  onSubmitIdentification: PropTypes.func.isRequired,
  className: PropTypes.string,
  currentUser: PropTypes.object
};

export default IdentificationForm;
