import React, { PropTypes } from "react";
import { Button, Input } from "react-bootstrap";
import safeHtml from "safe-html";
import TaxonAutocomplete from "./taxon_autocomplete";

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
      // All of the following coarser ID confirmation stuff is a hack to avoid
      // layering a modal on top of another modal. We either need a new design
      // solution for this notification, or the entire observation modal on
      // identify needs to be rethough as something other than a vanilla
      // bootstrap modal, e.g. something full screen and modal-ish without
      // really being modal.
      const idTaxon = $( ".IdentificationForm:visible:first input[name='taxon_name']" ).
        data( "uiAutocomplete" ).selectedItem;
      let confirmationText = safeHtml( I18n.t( "your_coarser_id", {
        coarser_taxon_name: idTaxon.name,
        finer_taxon_name: o.taxon.name
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
        currentUser && currentUser.prefers_skip_coarer_id_modal
      );
      if (
        isDisagreement( ) &&
        !currentUserSkippedConfirmation &&
        !confirm( confirmationText )
      ) {
        return;
      }
      onSubmitIdentification( {
        observation_id: o.id,
        taxon_id: e.target.elements.taxon_id.value,
        body: e.target.elements.body.value
      } );
      // this doesn't feel right... somehow submitting an ID should alter
      // the app state and this stuff should flow three here as props
      $( "input[name='taxon_name']", e.target ).trigger( "resetAll" );
      $( e.target.elements.body ).val( null );
    }}
  >
    <h3>{ I18n.t( "add_an_identification" ) }</h3>
    <TaxonAutocomplete />
    <Input type="textarea" name="body" className="form-control" />
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
