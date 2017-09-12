import _ from "lodash";
import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Input, Button } from "react-bootstrap";
import TaxonAutocomplete from "../../uploader/components/taxon_autocomplete";
import DateTimeFieldWrapper from "../../uploader/components/date_time_field_wrapper";

class ObservationFieldInput extends React.Component {

  constructor( props, context ) {
    super( props, context );
    this.state = {
      observationField: this.props.observationField,
      observationFieldValue: this.props.observationFieldValue,
      observationFieldTaxon: this.props.observationFieldTaxon
    };
    this.submitFieldValue = this.submitFieldValue.bind( this );
    this.onChangeHandler = this.onChangeHandler.bind( this );
    this.saveLabel = this.saveLabel.bind( this );
    this.saveDisabled = this.saveDisabled.bind( this );
  }

  componentDidMount( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  onChangeHandler( e ) {
    let modified = true;
    if ( _.isObject( e ) && e.target ) {
      modified = this.props.originalOfv ?
        !this.sameValue( $( e.target ).val( ), this.props.originalOfv.value ) : true;
    } else {
      modified = this.props.originalOfv ?
        !this.sameValue( e, this.props.originalOfv.value ) : true;
    }
    this.setState( { modified } );
  }

  setUpObservationFieldAutocomplete( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const input = $( domNode ).find( ".ofv-field" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.autocomplete( "destroy" );
      input.removeData( "uiAutocomplete" );
    }
    input.observationFieldAutocomplete( {
      resetOnChange: false,
      allowEnterSubmit: false,
      selectFirstMatch: true,
      notIDs: this.props.notIDs,
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

  sameValue( v1, v2 ) {
    /* eslint eqeqeq: 0 */
    // using == here instead of === or _.isEquals so we can compare
    // ints to strings, e.g. 10 == "10" is true
    return v1 == v2;
  }

  submitFieldValue( e ) {
    e.preventDefault( );
    if ( !this.state.observationField ) { return; }
    const valuesToSubmit = this.valuesToSubmit( );
    if ( !valuesToSubmit.value && valuesToSubmit.value !== 0 ) {
      const valueInput = $( e.target ).find( "[name='value'], [name='taxon_name']" );
      valueInput.addClass( "failed" );
      setTimeout( () => {
        valueInput.removeClass( "failed" );
      }, 1000 );
      return;
    }
    this.props.onSubmit( valuesToSubmit );
    if ( !this.props.noReset ) {
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
    if ( !this.state.observationField ) { return { }; }
    if ( ( !this.state.observationFieldValue && !value.val( ) ) ||
         ( this.state.observationField.datatype !== "taxon" && !value ) ) {
      return {
        observationField: this.state.observationField,
        value: null,
        initial: !!options.initial
      };
    }
    if ( this.state.observationField.datatype === "taxon" ) {
      return {
        observationField: this.state.observationField,
        value: this.state.observationFieldValue,
        taxon: this.state.observationFieldTaxon,
        initial: !!options.initial
      };
    }
    return {
      observationField: this.state.observationField,
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
    if ( this.props.editing ) {
      label = this.state.modified ? I18n.t( "save" ) : I18n.t( "saved" );
    }
    return label;
  }

  saveDisabled( ) {
    return this.props.editing && !this.state.modified;
  }

  selectInput( field ) {
    return (
      <Input
        type="select"
        name="value"
        defaultValue={ this.state.observationFieldValue }
        onChange={ this.onChangeHandler }
      >
        { _.map( field.allowed_values.split( "|" ), f => (
          <option value={ f } key={ f }>{ f }</option>
        ) ) }
      </Input>
    );
  }

  taxonInput( ) {
    const add = this.props.noAdd ? "" : (
      <span className="input-group-btn">
        <button
          className="btn btn-default"
          type="submit"
          disabled={ this.saveDisabled( ) }
        >
          { this.saveLabel( ) }
        </button>
      </span>
    );
    return (
      <div className="input-group">
        <TaxonAutocomplete
          bootstrap
          searchExternal
          showPlaceholder={ false }
          perPage={ 6 }
          initialSelection={ this.state.observationFieldTaxon }
          afterSelect={ r => {
            this.setState( {
              observationFieldTaxon: r.item,
              observationFieldValue: r.item.id
            } );
            this.onChangeHandler( r.item.id );
          } }
          afterUnselect={ ( ) => {
            this.setState( {
              observationFieldTaxon: null,
              observationFieldValue: null
            } );
            this.onChangeHandler( null );
          } }
          placeholder={ I18n.t( "species_name_cap" ) }
        />
        { add }
      </div>
    );
  }

  datetimeInput( datatype ) {
    /* global TIMEZONE */
    let mode;
    if ( datatype === "time" ) {
      mode = "time";
    } else if ( datatype === "date" ) {
      mode = "date";
    }
    let format = "YYYY/MM/DD h:mm A z";
    if ( datatype === "time" ) {
      format = "HH:mm";
    } else if ( datatype === "date" ) {
      format = "YYYY/MM/DD";
    }
    const add = this.props.noAdd ? "" : (
      <span className="input-group-btn">
        <button
          className="btn btn-default"
          type="submit"
          disabled={ this.saveDisabled( ) }
        >
          { this.saveLabel( ) }
        </button>
      </span>
    );
    return (
      <div className="input-group">
        <DateTimeFieldWrapper
          key={ `datetime${this.state.observationFieldSelectedDate}`}
          reactKey={ `datetime${this.state.observationFieldSelectedDate}`}
          ref="datetime"
          mode={ mode }
          inputFormat={ format }
          timeZone={ TIMEZONE }
          onChange={ dateString => {
            this.setState( { observationFieldValue: dateString } );
            this.onChangeHandler( dateString );
          } }
          onSelection={ dateString => {
            this.setState( {
              observationFieldValue: dateString,
              observationFieldSelectedDate: dateString
            } );
            this.onChangeHandler( dateString );
          } }
        />
        <input
          type="text"
          name="value"
          className="form-control"
          autoComplete="off"
          value={ this.state.observationFieldValue }
          onClick= { () => {
            if ( this.refs.datetime ) {
              this.refs.datetime.onClick( );
            }
          } }
          onChange= { e => {
            if ( this.refs.datetime ) {
              this.refs.datetime.onChange( undefined, e.target.value );
            }
          } }
          placeholder={ I18n.t( "date_time" ) }
        />
        { add }
      </div>
    );
  }

  dnaInput( ) {
    return ( <textarea
      name="value"
      className="form-control"
      defaultValue={ this.state.observationFieldValue }
      onChange={ this.onChangeHandler }
    /> );
  }

  defaultInput( ) {
    const add = this.props.noAdd ? "" : (
      <span className="input-group-btn">
        <button
          className="btn btn-default"
          type="submit"
          disabled={ this.saveDisabled( ) }
        >
          { this.saveLabel( ) }
        </button>
      </span>
    );
    return (
      <div className="input-group">
        <input
          type="text"
          name="value"
          defaultValue={ this.state.observationFieldValue }
          className="form-control"
          onChange={ this.onChangeHandler }
        />
        { add }
      </div>
    );
  }

  render( ) {
    const field = this.state.observationField;
    let observationFieldInput;
    if ( field ) {
      let input;
      let submit;
      const standaloneSubmit = this.props.noAdd ? "" : (
        <Button className="standalone" type="submit" disabled={ this.saveDisabled( ) }>
          { this.saveLabel( ) }
        </Button>
      );
      if ( field.allowed_values ) {
        input = this.selectInput( field );
        submit = standaloneSubmit;
      } else if ( field.datatype === "taxon" ) {
        input = this.taxonInput( );
      } else if ( field.datatype === "dna" ) {
        input = this.dnaInput( );
        submit = standaloneSubmit;
      } else if ( field.datatype === "datetime" ||
                  field.datatype === "time" ||
                  field.datatype === "date" ) {
        input = this.datetimeInput( field.datatype );
      } else {
        input = this.defaultInput( );
      }
      const cancel = this.props.noCancel ? "" : (
        <span
          className="linky"
          onClick={ ( ) => (
            this.props.onCancel ? this.props.onCancel( ) : this.reset( )
          ) }
        >{ I18n.t( "cancel" ) }</span>
      );
      const editingClass = this.props.editing ? "editing" : "";
      observationFieldInput = (
        <div className={ `observation-field ${field.datatype}-field ${editingClass}` }>
          <div className="field-name">
            { field.name }
            { this.props.required ? ( <span className="required">*</span> ) : "" }
          </div>
          { input }
          <p className="help-block">{ field.description }</p>
          { submit } { cancel }
        </div>
      );
    }
    const fieldChooser = this.props.hideFieldChooser ? "" : (
      <input type="text"
        placeholder={ this.props.placeholder }
        className="form-control ofv-field"
      /> );
    return (
      <form onSubmit={ this.submitFieldValue } className="ObservationFieldInput">
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
  placeholder: PropTypes.string
};

ObservationFieldInput.defaultProps = {
  placeholder: I18n.t( "choose_a_field" )
};

export default ObservationFieldInput;
