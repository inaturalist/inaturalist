import React, { PropTypes, Component } from "react";
import DateTimeField from "react-bootstrap-datetimepicker";
import moment from "moment-timezone";

class DateTimeFieldWrapper extends Component {

  constructor( props, context ) {
    super( props, context );
    this.onClick = this.onClick.bind( this );
    this.onChange = this.onChange.bind( this );
    this.close = this.close.bind( this );
    this.pickerState = this.pickerState.bind( this );
  }

  componentDidMount( ) {
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
    let value = inputValue;
    const eInt = parseInt( e, 10 );
    if ( e && eInt ) {
      const pickedDate = new Date( eInt );
      if ( pickedDate ) {
        value = this.props.timeZone ?
          moment( pickedDate ).tz( this.props.timeZone ).
            format( this.props.inputFormat || "YYYY/MM/DD h:mm A z" ) :
          moment.parseZone( pickedDate ).
            format( this.props.inputFormat || "YYYY/MM/DD h:mm A ZZ" );
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
    return (
      <DateTimeField
        ref="datetime"
        key="datetime"
        mode={ this.props.mode }
        size={ this.props.size }
        maxDate={ this.props.allowFutureDates ? null : moment( ) }
        inputProps={ this.props.inputProps }
        defaultText={ this.props.defaultText || "" }
        dateTime={ this.props.dateTime }
        inputFormat={this.props.inputFormat || "YYYY/MM/DD h:mm A ZZ"}
        onChange={ this.onChange }
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
  timeZone: PropTypes.string,
  mode: PropTypes.string,
  inputFormat: PropTypes.string,
  size: PropTypes.string,
  allowFutureDates: PropTypes.bool,
  dateTime: PropTypes.oneOfType( [
    React.PropTypes.string,
    React.PropTypes.number,
    React.PropTypes.object
  ] )
};

export default DateTimeFieldWrapper;
