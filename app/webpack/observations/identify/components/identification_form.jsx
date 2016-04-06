import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Button, Input } from "react-bootstrap";
import TaxonAutocomplete from "./taxon_autocomplete";

class IdentificationForm extends React.Component {
  setTaxon( taxon ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "[name='taxon_id']", domNode ).val( taxon ? taxon.id : null );
  }
  render( ) {
    const that = this;
    return (
      <form
        className={`IdentificationForm ${this.props.className}`}
        onSubmit={function ( e ) {
          e.preventDefault();
          that.props.onSubmitIdentification( {
            observation_id: that.props.observation.id,
            taxon_id: e.target.elements.taxon_id.value,
            body: e.target.elements.body.value
          } );
          // this doesn't feel right... somehow submitting an ID should alter
          // the app state and this stuff should flow three here as props
          $( "input[name='taxon_name']", e.target ).trigger( "resetAll" );
          $( e.target.elements.body ).val( "" );
          $( e.target ).hide( );
        }}
      >
        <h2>Add an Identification</h2>
        <TaxonAutocomplete />
        <Input type="textarea" name="body" className="form-control" />
        <Button type="submit">Save</Button>
      </form>
    );
  }
}

IdentificationForm.propTypes = {
  observation: PropTypes.object,
  onSubmitIdentification: PropTypes.func.isRequired,
  className: PropTypes.string
};

export default IdentificationForm;
