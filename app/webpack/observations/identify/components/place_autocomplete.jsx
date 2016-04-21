import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Input } from "react-bootstrap";

class PlaceAutocomplete extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const opts = Object.assign( {}, ...this.props, {
      idEl: $( "input[name='place_id']", domNode )
    } );
    $( "input[name='place_name']", domNode ).placeAutocomplete( opts );
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
