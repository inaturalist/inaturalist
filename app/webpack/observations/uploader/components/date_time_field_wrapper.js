import React, { PropTypes, Component } from "react";
import ReactDOM from "react-dom";
import DateTimeField from "react-bootstrap-datetimepicker";
import moment from "moment";

class DateTimeFieldWrapper extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
  }

  componentDidMount( ) {
    // the datetime picker prevents a card drag preview without this
    this.close( );
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
          onClick: () => {
            if ( this.refs.datetime ) {
              this.refs.datetime.onClick( );
              const domNode = ReactDOM.findDOMNode( this.refs.datetime );
              $( "input", domNode ).focus( );
            }
          }
        }}
        onChange={ e => {
          const domNode = ReactDOM.findDOMNode( this.refs.datetime );
          let inputValue = $( "input", domNode ).val( );
          const eInt = parseInt( e, 10 );
          if ( e && eInt ) {
            const pickedDate = new Date( eInt );
            if ( pickedDate ) {
              inputValue = moment( pickedDate ).format( "MM/DD/YY h:mm A ZZ" );
            }
          }
          this.props.onChange( inputValue );
        } }
      />
    );
  }
}

DateTimeFieldWrapper.propTypes = {
  onChange: PropTypes.func,
  defaultText: PropTypes.string
};

export default DateTimeFieldWrapper;
