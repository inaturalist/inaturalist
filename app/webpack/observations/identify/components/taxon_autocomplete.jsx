import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Input } from "react-bootstrap";

class TaxonAutocomplete extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "input[name='taxon_name']", domNode ).taxonAutocomplete( {
      resetOnChange: this.props.resetOnChange,
      bootstrapClear: this.props.bootstrapClear,
      search_external: this.props.searchExternal,
      id_el: $( "input[name='taxon_id']", domNode ),
      afterSelect: this.props.afterSelect,
      afterUnselect: this.props.afterUnselect
    } );
  }

  render( ) {
    return (
      <span>
        <Input
          type="search"
          name="taxon_name"
          className="form-control"
          placeholder={ I18n.t( "species" ) }
        />
        <Input type="hidden" name="taxon_id" />
      </span>
    );
  }
}


TaxonAutocomplete.propTypes = {
  resetOnChange: PropTypes.bool,
  bootstrapClear: PropTypes.bool,
  searchExternal: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func
};

export default TaxonAutocomplete;
