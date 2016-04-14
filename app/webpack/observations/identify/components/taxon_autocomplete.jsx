import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Input } from "react-bootstrap";
import inaturalistjs from "inaturalistjs";

class TaxonAutocomplete extends React.Component {

  constructor( props, context ) {
    super( props, context );
    this.fetchTaxon = this.fetchTaxon.bind( this );
  }

  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "input[name='taxon_name']", domNode ).taxonAutocomplete( {
      resetOnChange: this.props.resetOnChange,
      bootstrapClear: this.props.bootstrapClear,
      search_external: this.props.searchExternal,
      allow_placeholders: this.props.allowPlaceholders,
      show_placeholder: this.props.showPlaceholder,
      per_page: this.props.perPage,
      id_el: $( "input[name='taxon_id']", domNode ),
      afterSelect: this.props.afterSelect,
      afterUnselect: this.props.afterUnselect,
      initialSelection: this.props.initialSelection
    } );
    this.fetchTaxon( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialTaxonID &&
         this.props.initialTaxonID !== prevProps.initialTaxonID ) {
      this.fetchTaxon( );
    }
  }

  fetchTaxon( ) {
    if ( this.props.initialTaxonID ) {
      inaturalistjs.taxa.fetch( this.props.initialTaxonID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateTaxon( { taxon: r.results[0] } );
        }
      } );
    }
  }

  updateTaxon( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.taxon ) {
      $( "input[name='taxon_name']", domNode ).
        trigger( "assignSelection", options.taxon );
    }
  }

  render( ) {
    return (
      <span className="TaxonAutocomplete">
        <Input
          type="search"
          name="taxon_name"
          className="form-control"
          onChange={this.props.onChange}
          placeholder={ I18n.t( "species" ) }
        />
        <Input type="hidden" name="taxon_id" />
      </span>
    );
  }
}

TaxonAutocomplete.propTypes = {
  onChange: PropTypes.func,
  resetOnChange: PropTypes.bool,
  bootstrapClear: PropTypes.bool,
  searchExternal: PropTypes.bool,
  showPlaceholder: PropTypes.bool,
  allowPlaceholders: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  initialSelection: PropTypes.object,
  initialTaxonID: PropTypes.number,
  perPage: PropTypes.number
};

export default TaxonAutocomplete;
