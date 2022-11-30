import React, { Component } from "react";
import PropTypes from "prop-types";
import DateTimeField from "react-bootstrap-datetimepicker";
import moment from "moment";
import { parsableDatetimeFormat } from "../models/util";

class DateTimeFieldWrapper extends Component {
  constructor( props, context ) {
    super( props, context );
    this.onClick = this.onClick.bind( this );
    this.onChange = this.onChange.bind( this );
    this.close = this.close.bind( this );
    this.pickerState = this.pickerState.bind( this );
  }

  componentDidMount( ) {
    moment.locale( I18n.locale );
    // the datetime picker prevents a card drag preview without this
    this.close( );
  }

  shouldComponentUpdate( nextProps ) {
    if ( this.props.reactKey === nextProps.reactKey ) { return false; }
    return true;
  }

  onClick( ) {
    if ( this.refs.datetime ) {
      this.refs.datetime.onClick( );
    }
  }

  onChange( e, inputValue ) {
    const { inputFormat } = this.props;
    let value = inputValue;
    const eInt = parseInt( e, 10 );
    const dateTimeFormat = parsableDatetimeFormat( );
    if ( e && eInt ) {
      const pickedDate = new Date( eInt );
      if ( pickedDate ) {
        value = moment( pickedDate ).format( inputFormat || dateTimeFormat );
      }
    }
    this.props.onChange( value );
  }

  close( ) {
    if ( this.refs.datetime ) { this.refs.datetime.closePicker( ); }
  }

  pickerState( ) {
    if ( this.refs.datetime ) { return this.refs.datetime.state; }
    return undefined;
  }

  render( ) {
    const {
      allowFutureDates,
      dateTime,
      defaultText,
      inputFormat,
      inputProps,
      minDate,
      mode,
      size
    } = this.props;
    return (
      <DateTimeField
        ref="datetime"
        key="datetime"
        className="datetime"
        mode={mode}
        size={size}
        minDate={minDate || moment( ).subtract( 130, "years" )}
        maxDate={allowFutureDates ? null : moment( )}
        inputProps={inputProps}
        defaultText={defaultText || ""}
        dateTime={dateTime}
        inputFormat={inputFormat || parsableDatetimeFormat( )}
        onChange={this.onChange}
      />
    );
  }
}

DateTimeFieldWrapper.propTypes = {
  inputProps: PropTypes.object,
  onChange: PropTypes.func,
  onSelection: PropTypes.func,
  reactKey: PropTypes.string,
  defaultText: PropTypes.string,
  mode: PropTypes.string,
  inputFormat: PropTypes.string,
  size: PropTypes.string,
  allowFutureDates: PropTypes.bool,
  dateTime: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number,
    PropTypes.object
  ] ),
  minDate: PropTypes.object
};

export default DateTimeFieldWrapper;
