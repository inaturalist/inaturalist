import React from "react";
import PropTypes from "prop-types";
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
      idEl: $( "input[name='taxon_id']", domNode ),
      preventEnterSubmit: true,
      react: true,
      user: this.props.config && this.props.config.user
    } );
    $( "input[name='taxon_name']", domNode ).taxonAutocomplete( opts );
    this.fetchTaxon( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialTaxonID !== prevProps.initialTaxonID ) {
      this.fetchTaxon( );
    }
  }

  fetchTaxon( ) {
    if ( this.props.initialTaxonID && !this.props.initialSelection ) {
      inaturalistjs.taxa.fetch( this.props.initialTaxonID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateTaxon( { taxon: r.results[0] } );
        }
      } );
    } else {
      this.updateTaxon( { taxon: this.props.initialSelection } );
    }
  }

  updateTaxon( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.taxon ) {
      $( "input[name='taxon_name']", domNode ).
        trigger( "assignSelection", options.taxon );
    } else {
      $( "input[name='taxon_name']", domNode ).
        trigger( "resetAll" );
    }
  }

  render( ) {
    return (
      <span className={`TaxonAutocomplete ${this.props.className}`}>
        <div className="form-group">
          <input
            type="search"
            name="taxon_name"
            value={this.props.value}
            className={`form-control ${this.props.inputClassName}`}
            onChange={this.props.onChange}
            placeholder={ this.props.placeholder }
            autoComplete="off"
          />
        </div>
        <input type="hidden" name="taxon_id" />
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
  value: PropTypes.string,
  initialSelection: PropTypes.object,
  initialTaxonID: PropTypes.number,
  perPage: PropTypes.number,
  className: PropTypes.string,
  inputClassName: PropTypes.string,
  position: PropTypes.object,
  placeholder: PropTypes.string,
  config: PropTypes.object
};

TaxonAutocomplete.defaultProps = {
  placeholder: I18n.t( "species" ),
  config: {}
};

export default TaxonAutocomplete;
