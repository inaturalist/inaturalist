import React, { PropTypes } from "react";
import { Button } from "react-bootstrap";
import safeHtml from "safe-html";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import INatTextArea from "./inat_text_area";

const IdentificationForm = ( {
  observation: o,
  onSubmitIdentification,
  className,
  blind
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
        if ( !o || !o.taxon ) {
          return false;
        }
        return o.taxon.id !== idTaxon.id && o.taxon.ancestor_ids.indexOf( idTaxon.id ) > 0;
      };
      const params = {
        observation_id: o.id,
        taxon_id: e.target.elements.taxon_id.value,
        body: e.target.elements.body.value,
        blind
      };
      if ( blind && isDisagreement( ) && e.target.elements.dont_disagree ) {
        params.disagreement = !$( e.target.elements.dont_disagree ).prop( "checked" );
      }
      onSubmitIdentification( params, {
        observation: o,
        potentialDisagreement: !blind && isDisagreement( )
      } );
      // this doesn't feel right... somehow submitting an ID should alter
      // the app state and this stuff should flow three here as props
      $( "input[name='taxon_name']", e.target ).trigger( "resetAll" );
      $( e.target.elements.body ).val( null );
      $( e.target.elements.dont_disagree ).prop( "checked", false );
    }}
  >
    <h3>{ I18n.t( "add_an_identification" ) }</h3>
    <TaxonAutocomplete />
    <INatTextArea type="textarea" name="body" className="form-control" mentions />
    { blind ? (
      <div className="form-group">
        <label>
          <input type="checkbox" name="dont_disagree" /> Others could potentially refine this ID
        </label>
      </div>
    ) : null }
    <Button type="submit" bsStyle="success">{ I18n.t( "save" ) }</Button>
  </form>
);

IdentificationForm.propTypes = {
  observation: PropTypes.object,
  onSubmitIdentification: PropTypes.func.isRequired,
  className: PropTypes.string,
  currentUser: PropTypes.object,
  blind: PropTypes.bool
};

export default IdentificationForm;
