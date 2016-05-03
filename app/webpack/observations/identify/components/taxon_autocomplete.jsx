import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import inaturalistjs from "inaturalistjs";

class TaxonAutocomplete extends React.Component {

  constructor( props, context ) {
    super( props, context );
    this.fetchTaxon = this.fetchTaxon.bind( this );
  }

  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const opts = Object.assign( {}, this.props, {
      idEl: $( "input[name='taxon_id']", domNode )
    } );
    $( "input[name='taxon_name']", domNode ).taxonAutocomplete( opts );
    this.fetchTaxon( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialTaxonID &&
         this.props.initialTaxonID !== prevProps.initialTaxonID ) {
      this.fetchTaxon( );
    }
  }

  componentWillUnmount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "input[name='taxon_name']", domNode ).autocomplete( "destroy" );
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
      <div className="TaxonAutocomplete">
        <div className="form-group">
          <input type="hidden" name="taxon_id" />
          <input
            type="text"
            name="taxon_name"
            value={ this.props.value }
            className={ `form-control ${this.props.small && "input-sm"}` }
            onChange={ this.props.onChange }
            placeholder="Species Name"
            autoComplete="off"
          />
        </div>
      </div>
    );
  }
}

TaxonAutocomplete.propTypes = {
  onChange: PropTypes.func,
  small: PropTypes.bool,
  resetOnChange: PropTypes.bool,
  bootstrapClear: PropTypes.bool,
  bootstrap: PropTypes.bool,
  searchExternal: PropTypes.bool,
  showPlaceholder: PropTypes.bool,
  allowPlaceholders: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  value: PropTypes.string,
  initialSelection: PropTypes.object,
  initialTaxonID: PropTypes.number,
  perPage: PropTypes.number
};

export default TaxonAutocomplete;
