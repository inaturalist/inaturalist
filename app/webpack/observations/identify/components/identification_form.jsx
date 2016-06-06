import React, { PropTypes } from "react";
import { Button, Input } from "react-bootstrap";
import TaxonAutocomplete from "./taxon_autocomplete";

const IdentificationForm = ( {
  observation,
  onSubmitIdentification,
  className
} ) => (
  <form
    className={`IdentificationForm ${className}`}
    onSubmit={function ( e ) {
      e.preventDefault();
      onSubmitIdentification( {
        observation_id: observation.id,
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
  className: PropTypes.string
};

export default IdentificationForm;
