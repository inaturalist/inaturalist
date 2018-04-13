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
        if ( !o || !( o.community_taxon || o.taxon ) ) {
          return false;
        }
        let observationTaxon = o.taxon;
        if ( o.preferences.prefers_community_taxon === false || o.user.preferences.prefers_community_taxa === false ) {
          observationTaxon = o.community_taxon || o.taxon;
        }
        return observationTaxon.id !== idTaxon.id && observationTaxon.ancestor_ids.indexOf( idTaxon.id ) > 0;
      };
      const params = {
        observation_id: o.id,
        taxon_id: e.target.elements.taxon_id.value,
        body: e.target.elements.body.value,
        blind
      };
      if ( blind && isDisagreement( ) && e.target.elements.disagreement ) {
        params.disagreement = e.target.elements.disagreement.value === "1";
      }
      onSubmitIdentification( params, {
        observation: o,
        taxon: idTaxon,
        potentialDisagreement: !blind && isDisagreement( )
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
    { blind ? (
      <div className="form-group disagreement-group">
        <label>
          <input
            type="radio"
            name="disagreement"
            value="0"
            defaultChecked
          /> Others could potentially refine this ID
        </label>
        <label>
          <input type="radio" name="disagreement" value="1" /> This is the most specific ID the evidence justifies
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
