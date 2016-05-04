import React, { PropTypes, Component } from "react";
import DateTimeField from "react-bootstrap-datetimepicker";
import moment from "moment";

class DateTimeFieldWrapper extends Component {

  constructor( props, context ) {
    super( props, context );
    this.onClick = this.onClick.bind( this );
    this.onChange = this.onChange.bind( this );
    this.close = this.close.bind( this );
  }

  componentDidMount( ) {
    // the datetime picker prevents a card drag preview without this
    this.close( );
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
        value = moment.parseZone( pickedDate ).format( "YYYY/MM/DD h:mm A ZZ" );
      }
    }
    this.props.onChange( value );
  }

  close( ) {
    if ( this.refs.datetime ) { this.refs.datetime.closePicker( ); }
  }

  render( ) {
    return (
      <DateTimeField
        ref="datetime"
        maxDate={ moment( ) }
        inputFormat="YYYY/MM/DD h:mm A ZZ"
        onChange={ this.onChange }
      />
    );
  }
}

DateTimeFieldWrapper.propTypes = {
  onChange: PropTypes.func,
  onSelection: PropTypes.func,
  defaultText: PropTypes.string
};

export default DateTimeFieldWrapper;
