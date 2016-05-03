import React, { PropTypes, Component } from "react";
import ReactDOM from "react-dom";
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
    const eInt = parseInt( e, 10 );
    if ( e && eInt ) {
      const pickedDate = new Date( eInt );
      if ( pickedDate ) {
        inputValue = moment.parseZone( pickedDate ).format( "MM/DD/YY h:mm A ZZ" );
      }
    }
    this.props.onChange( inputValue );
  }

  close( ) {
    if ( this.refs.datetime ) { this.refs.datetime.closePicker( ); }
  }

  render( ) {
    return (
      <DateTimeField
        ref="datetime"
        maxDate={ moment( ) }
        defaultText={ this.props.defaultText || "" }
        inputFormat="MM/DD/YY h:mm A ZZ"
        inputProps={ {
          className: "form-control input-sm",
          placeholder: "Add Date/Time"
        }}
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
