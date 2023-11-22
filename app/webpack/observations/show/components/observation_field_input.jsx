import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import { Button } from "react-bootstrap";
import TaxonAutocomplete from "../../uploader/components/taxon_autocomplete";
import DateTimeFieldWrapper from "../../uploader/components/date_time_field_wrapper";
import { parsableDatetimeFormat } from "../../uploader/models/util";

class ObservationFieldInput extends React.Component {
  static sameValue( v1, v2 ) {
    /* eslint eqeqeq: 0 */
    // using == here instead of === or _.isEquals so we can compare
    // ints to strings, e.g. 10 == "10" is true
    return v1 == v2;
  }

  constructor( props, context ) {
    super( props, context );
    const {
      observationField,
      observationFieldValue,
      observationFieldTaxon
    } = this.props;
    this.state = {
      observationField,
      observationFieldValue,
      observationFieldTaxon
    };
    this.submitFieldValue = this.submitFieldValue.bind( this );
    this.onChangeHandler = this.onChangeHandler.bind( this );
    this.saveLabel = this.saveLabel.bind( this );
    this.saveDisabled = this.saveDisabled.bind( this );
  }

  componentDidMount( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  componentDidUpdate( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const observationFieldTaxon = this.state;
    // prevent the taxon chooser from opening again after selecting a taxon
    if ( !observationFieldTaxon ) {
      $( ".observation-field :input:visible:first", domNode ).focus( );
    }
  }

  onChangeHandler( e ) {
    const { originalOfv } = this.props;
    let modified = true;
    if ( _.isObject( e ) && e.target ) {
      modified = originalOfv
        ? !ObservationFieldInput.sameValue( $( e.target ).val( ), originalOfv.value ) : true;
    } else {
      modified = originalOfv ? !ObservationFieldInput.sameValue( e, originalOfv.value ) : true;
    }
    this.setState( { modified } );
  }

  setUpObservationFieldAutocomplete( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const { notIDs } = this.props;
    const input = $( domNode ).find( ".ofv-field" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.autocomplete( "destroy" );
      input.removeData( "uiAutocomplete" );
    }
    input.observationFieldAutocomplete( {
      resetOnChange: false,
      allowEnterSubmit: false,
      selectFirstMatch: true,
      notIDs,
      idEl: $( "<input/>" ),
      onResults: items => {
        if ( items !== null && items.length === 0 && input.val( ).length > 0 ) {
          input.addClass( "failed" );
        } else {
          input.removeClass( "failed" );
        }
      },
      afterSelect: p => {
        if ( p ) {
          this.setState( {
            observationField: p.item,
            observationFieldValue: null,
            observationFieldSelectedDate: null
          } );
        }
        input.val( "" ).blur( );
      }
    } );
  }

  submitFieldValue( e ) {
    e.preventDefault( );
    const { observationField } = this.state;
    const { onSubmit, noReset } = this.props;
    if ( !observationField ) { return; }
    const valuesToSubmit = this.valuesToSubmit( );
    if ( !valuesToSubmit.value && valuesToSubmit.value !== 0 ) {
      const valueInput = $( e.target ).find( "[name='value'], [name='taxon_name']" );
      valueInput.addClass( "failed" );
      setTimeout( () => {
        valueInput.removeClass( "failed" );
      }, 1000 );
      return;
    }
    onSubmit( valuesToSubmit );
    if ( !noReset ) {
      this.reset( );
    } else {
      this.setState( {
        modified: false
      } );
    }
  }

  valuesToSubmit( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    const value = $( domNode ).find( "[name='value']" );
    const {
      observationField,
      observationFieldValue,
      observationFieldTaxon
    } = this.state;
    if ( !observationField ) { return { }; }
    if (
      ( !observationFieldValue && !value.val( ) )
      || ( observationField.datatype !== "taxon" && !value )
    ) {
      return {
        observationField,
        value: null,
        initial: !!options.initial
      };
    }
    if ( observationField.datatype === "taxon" ) {
      return {
        observationField,
        value: observationFieldValue,
        taxon: observationFieldTaxon,
        initial: !!options.initial
      };
    }
    return {
      observationField,
      value: value.val( ),
      initial: !!options.initial
    };
  }

  reset( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const value = $( domNode ).find( "[name='value']" );
    const input = $( domNode ).find( "input.ofv-input" );
    this.setState( {
      observationField: null,
      observationFieldValue: null,
      observationFieldTaxon: null
    } );
    value.val( "" );
    input.val( "" ).blur( );
  }

  saveLabel( ) {
    let label = I18n.t( "add" );
    const { editing, modified } = this.state;
    if ( editing ) {
      label = modified ? I18n.t( "save" ) : I18n.t( "saved" );
    }
    return label;
  }

  inlineAdd( ) {
    const { noAdd } = this.props;
    return noAdd ? "" : (
      <span className="input-group-btn">
        <button
          className="btn btn-default"
          type="submit"
          disabled={this.saveDisabled( )}
        >
          { this.saveLabel( ) }
        </button>
      </span>
    );
  }

  saveDisabled( ) {
    const { editing } = this.props;
    const { modified } = this.state;
    return editing && !modified;
  }

  selectInput( field ) {
    const { observationFieldValue } = this.state;
    return (
      <select
        name="value"
        className="form-control"
        defaultValue={observationFieldValue}
        onChange={this.onChangeHandler}
      >
        { _.map( field.allowed_values.split( "|" ), f => (
          <option value={f} key={f}>{ f }</option>
        ) ) }
      </select>
    );
  }

  taxonInput( ) {
    const { config } = this.props;
    const { observationFieldTaxon } = this.state;
    return (
      <div className="input-group">
        <TaxonAutocomplete
          bootstrap
          searchExternal
          showPlaceholder={false}
          perPage={6}
          initialSelection={observationFieldTaxon}
          afterSelect={r => {
            this.setState( {
              observationFieldTaxon: r.item,
              observationFieldValue: r.item.id
            } );
            this.onChangeHandler( r.item.id );
          }}
          afterUnselect={( ) => {
            this.setState( {
              observationFieldTaxon: null,
              observationFieldValue: null
            } );
            this.onChangeHandler( null );
          }}
          placeholder={I18n.t( "species_name_cap" )}
          config={config}
        />
        { this.inlineAdd( ) }
      </div>
    );
  }

  datetimeInput( datatype ) {
    /* global TIMEZONE */
    const { observationFieldSelectedDate, observationFieldValue } = this.state;
    let mode;
    if ( datatype === "time" ) {
      mode = "time";
    } else if ( datatype === "date" ) {
      mode = "date";
    }
    let format = parsableDatetimeFormat( );
    if ( datatype === "time" ) {
      format = "HH:mm";
    } else if ( datatype === "date" ) {
      format = "YYYY/MM/DD";
    }
    return (
      <div className="input-group">
        <DateTimeFieldWrapper
          key={`datetime${observationFieldSelectedDate}`}
          reactKey={`datetime${observationFieldSelectedDate}`}
          ref="datetime"
          mode={mode}
          inputFormat={format}
          onChange={dateString => {
            this.setState( { observationFieldValue: dateString } );
            this.onChangeHandler( dateString );
          }}
          onSelection={dateString => {
            this.setState( {
              observationFieldValue: dateString,
              observationFieldSelectedDate: dateString
            } );
            this.onChangeHandler( dateString );
          }}
        />
        <input
          type="text"
          name="value"
          className="form-control"
          autoComplete="off"
          value={observationFieldValue || ""}
          onClick={() => {
            const { datetime } = this.refs;
            if ( datetime ) {
              datetime.onClick( );
            }
          }}
          onChange={e => {
            const { datetime } = this.refs;
            if ( datetime ) {
              datetime.onChange( undefined, e.target.value );
            }
          }}
          placeholder={I18n.t( "date_time" )}
        />
        { this.inlineAdd( ) }
      </div>
    );
  }

  dnaInput( ) {
    const { observationFieldValue } = this.state;
    return (
      <textarea
        name="value"
        className="form-control"
        defaultValue={observationFieldValue}
        onChange={this.onChangeHandler}
      />
    );
  }

  numericInput( ) {
    const { observationFieldValue } = this.state;
    return (
      <div className="input-group">
        <input
          type="number"
          name="value"
          step="any"
          defaultValue={observationFieldValue}
          className="form-control"
          onChange={this.onChangeHandler}
        />
        { this.inlineAdd( ) }
      </div>
    );
  }

  defaultInput( ) {
    const { observationFieldValue } = this.state;
    return (
      <div className="input-group">
        <input
          type="text"
          name="value"
          defaultValue={observationFieldValue}
          className="form-control"
          onChange={this.onChangeHandler}
        />
        { this.inlineAdd( ) }
      </div>
    );
  }

  render( ) {
    const { observationField: field } = this.state;
    const {
      noAdd,
      noCancel,
      onCancel,
      editing,
      required,
      hideFieldChooser,
      placeholder,
      disabled
    } = this.props;
    let observationFieldInput;
    if ( field ) {
      let input;
      let submit;
      const standaloneSubmit = noAdd ? "" : (
        <Button className="standalone" type="submit" disabled={this.saveDisabled( )}>
          { this.saveLabel( ) }
        </Button>
      );
      if ( field.allowed_values ) {
        input = this.selectInput( field );
        submit = standaloneSubmit;
      } else if ( field.datatype === "numeric" ) {
        input = this.numericInput( );
      } else if ( field.datatype === "taxon" ) {
        input = this.taxonInput( );
      } else if ( field.datatype === "dna" ) {
        input = this.dnaInput( );
        submit = standaloneSubmit;
      } else if (
        field.datatype === "datetime"
        || field.datatype === "time"
        || field.datatype === "date"
      ) {
        input = this.datetimeInput( field.datatype );
      } else {
        input = this.defaultInput( );
      }
      const cancel = noCancel ? "" : (
        <span
          className="linky"
          onClick={( ) => (
            onCancel ? onCancel( ) : this.reset( )
          )}
        >
          { I18n.t( "cancel" ) }
        </span>
      );
      const editingClass = editing ? "editing" : "";
      observationFieldInput = (
        <div className={`observation-field ${field.datatype}-field ${editingClass}`}>
          <div className="field-name">
            { field.name }
            { required ? ( <span className="required">*</span> ) : "" }
          </div>
          { input }
          <p className="help-block">{ field.description }</p>
          { submit }
          { " " }
          { cancel }
        </div>
      );
    }
    const fieldChooser = hideFieldChooser ? "" : (
      <input
        type="text"
        placeholder={placeholder}
        className="form-control ofv-field"
        disabled={disabled}
      /> );
    return (
      <form onSubmit={this.submitFieldValue} className="ObservationFieldInput">
        { fieldChooser }
        { observationFieldInput }
      </form>
    );
  }
}

ObservationFieldInput.propTypes = {
  observationField: PropTypes.object,
  observationFieldTaxon: PropTypes.object,
  observationFieldValue: PropTypes.any,
  editing: PropTypes.bool,
  hideFieldChooser: PropTypes.bool,
  noAdd: PropTypes.bool,
  noCancel: PropTypes.bool,
  noReset: PropTypes.bool,
  notIDs: PropTypes.array,
  onCancel: PropTypes.func,
  onSubmit: PropTypes.func,
  originalOfv: PropTypes.object,
  required: PropTypes.bool,
  placeholder: PropTypes.string,
  config: PropTypes.object,
  disabled: PropTypes.bool
};

ObservationFieldInput.defaultProps = {
  placeholder: I18n.t( "choose_a_field" )
};

export default ObservationFieldInput;
