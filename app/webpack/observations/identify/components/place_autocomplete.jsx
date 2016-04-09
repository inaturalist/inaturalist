import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Input } from "react-bootstrap";

class PlaceAutocomplete extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "input[name='place_name']", domNode ).placeAutocomplete( {
      resetOnChange: this.props.resetOnChange,
      bootstrapClear: this.props.bootstrapClear,
      id_el: $( "input[name='place_id']", domNode ),
      afterSelect: this.props.afterSelect,
      afterUnselect: this.props.afterUnselect,
      initialSelection: this.props.initialSelection
    } );
  }

  render( ) {
    return (
      <span className="PlaceAutocomplete">
        <Input
          type="search"
          name="place_name"
          className="form-control"
          placeholder={ I18n.t( "place" ) }
        />
        <Input type="hidden" name="place_id" />
      </span>
    );
  }
}


PlaceAutocomplete.propTypes = {
  resetOnChange: PropTypes.bool,
  bootstrapClear: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  initialSelection: PropTypes.object
};

export default PlaceAutocomplete;
