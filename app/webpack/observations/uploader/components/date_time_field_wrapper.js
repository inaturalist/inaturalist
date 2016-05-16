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
        mode={this.props.mode}
        size={this.props.size}
        maxDate={ moment( ) }
        defaultText={ this.props.defaultText || "" }
        inputFormat={ this.props.inputFormat || "MM/DD/YY h:mm A ZZ" }
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
              inputValue = moment( pickedDate ).format(
                this.props.inputFormat || "MM/DD/YY h:mm A ZZ"
              );
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
  defaultText: PropTypes.string,
  mode: PropTypes.string,
  inputFormat: PropTypes.string,
  size: PropTypes.string,
  dateTime: PropTypes.oneOfType( [
    React.PropTypes.string,
    React.PropTypes.number,
    React.PropTypes.object
  ] )
};

export default DateTimeFieldWrapper;
