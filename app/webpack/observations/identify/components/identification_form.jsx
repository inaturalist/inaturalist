import React, { PropTypes } from "react";
import { Button } from "react-bootstrap";

const IdentificationForm = ( { observation, onSubmitIdentification } ) => (
  <form
    onSubmit={function ( e ) {
      e.preventDefault();
      onSubmitIdentification( {
        observation_id: observation.id,
        taxon_id: e.target.elements.taxon_id.value,
        body: e.target.elements.body.value
      } );
    }}
  >
    <h2>Add an Identification</h2>
    <input type="text" name="taxon_id" className="form-control" />
    <textarea name="body" className="form-control"></textarea>
    <Button type="submit">Save</Button>
  </form>
);

IdentificationForm.propTypes = {
  observation: PropTypes.object,
  onSubmitIdentification: PropTypes.func.isRequired
};

export default IdentificationForm;
