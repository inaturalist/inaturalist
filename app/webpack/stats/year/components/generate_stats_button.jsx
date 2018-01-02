import React from "react";
import { Button } from "react-bootstrap";
import { fetch } from "../../../shared/util";

class GenerateStatsButton extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      loading: false
    };
  }

  generateStats( ) {
    this.setState( { loading: true } );
    const data = new FormData( );
    data.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
    data.append( "year", this.props.year );
    fetch( "/stats/generate_year", {
      method: "POST",
      body: data
    } ).then( response => {
      if ( response.status === 200 ) {
        window.location.reload( );
      } else if ( response.status === 202 ) {
        setTimeout( ( ) => {
          this.generateStats( );
        }, 2000 );
      } else {
        alert( I18n.t( "this_job_failed_to_run" ) );
        this.setState( { loading: false } );
      }
    } ).catch( error => {
      console.log( "[DEBUG] error: ", error );
    } );
  }
  render( ) {
    return (
      <Button
        className="GenerateStatsButton"
        onClick={ ( ) => this.generateStats( ) }
        disabled={ this.state.loading }
      >
        <i className={`fa fa-refresh ${this.state.loading ? "fa-spin" : ""}`}>
        </i> { this.state.loading ? I18n.t( "loading" ) : this.props.text }
      </Button>
    );
  }
}

GenerateStatsButton.propTypes = {
  user: React.PropTypes.object,
  text: React.PropTypes.string,
  year: React.PropTypes.number.isRequired
};

GenerateStatsButton.defaultProps = {
  text: I18n.t( "generate_your_stats" )
};

export default GenerateStatsButton;
