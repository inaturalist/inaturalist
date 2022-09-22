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
    const { config } = this.props;
    const domNode = ReactDOM.findDOMNode( this );
    const opts = {
      ...this.props,
      idEl: $( "input[name='taxon_id']", domNode ),
      preventEnterSubmit: true,
      react: true,
      user: config && config.user,
      useAPIv2: config && config.testingApiV2
    };
    $( "input[name='taxon_name']", domNode ).taxonAutocomplete( opts );
    this.fetchTaxon( );
  }

  componentDidUpdate( prevProps ) {
    const { initialTaxonID } = this.props;
    if ( initialTaxonID !== prevProps.initialTaxonID ) {
      this.fetchTaxon( );
    }
  }

  fetchTaxon( ) {
    const { initialTaxonID, initialSelection } = this.props;
    if ( initialTaxonID && !initialSelection ) {
      inaturalistjs.taxa.fetch( initialTaxonID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateTaxon( { taxon: r.results[0] } );
        }
      } );
    } else {
      this.updateTaxon( { taxon: initialSelection } );
    }
  }

  updateTaxon( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.taxon ) {
      $( "input[name='taxon_name']", domNode )
        .trigger( "assignSelection", options.taxon );
    } else {
      $( "input[name='taxon_name']", domNode )
        .trigger( "resetAll" );
    }
  }

  render( ) {
    const {
      className,
      value,
      inputClassName,
      onChange,
      placeholder
    } = this.props;
    return (
      <span className={`TaxonAutocomplete ${className}`}>
        <div className="form-group">
          <input
            type="search"
            name="taxon_name"
            value={value}
            className={`form-control ${inputClassName}`}
            onChange={onChange}
            placeholder={placeholder}
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
  // eslint-disable-next-line react/no-unused-prop-types
  resetOnChange: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  bootstrapClear: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  searchExternal: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  showPlaceholder: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  allowPlaceholders: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  afterSelect: PropTypes.func,
  // eslint-disable-next-line react/no-unused-prop-types
  afterUnselect: PropTypes.func,
  value: PropTypes.string,
  initialSelection: PropTypes.object,
  initialTaxonID: PropTypes.number,
  // eslint-disable-next-line react/no-unused-prop-types
  perPage: PropTypes.number,
  className: PropTypes.string,
  inputClassName: PropTypes.string,
  // eslint-disable-next-line react/no-unused-prop-types
  position: PropTypes.object,
  placeholder: PropTypes.string,
  config: PropTypes.object
};

TaxonAutocomplete.defaultProps = {
  placeholder: I18n.t( "search_species" ),
  config: {}
};

export default TaxonAutocomplete;
