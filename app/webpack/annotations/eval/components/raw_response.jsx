import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Button } from "react-bootstrap";

class RawResponse extends Component {
  constructor( props, context ) {
    super( props, context );
    this.state = { expanded: false, showAll: false, copied: false };
  }

  copy( json ) {
    if ( !navigator.clipboard ) { return; }
    navigator.clipboard.writeText( json ).then( ( ) => {
      this.setState( { copied: true } );
      setTimeout( ( ) => this.setState( { copied: false } ), 2000 );
    } );
  }

  render( ) {
    const { response } = this.props;
    const { expanded, showAll, copied } = this.state;
    if ( _.isEmpty( response ) ) { return null; }

    const trimmed = _.omit( response, ["results"] );
    const shown = showAll ? response : trimmed;
    const json = JSON.stringify( shown, null, 2 );
    const resultCount = _.size( response.results );

    return (
      <div className="raw-response">
        <div className="raw-response-header">
          <Button bsSize="small" onClick={( ) => this.setState( { expanded: !expanded } )}>
            <i className={`fa fa-chevron-${expanded ? "down" : "right"}`} />
            &nbsp;
            Vision API response
          </Button>
          { expanded && (
            <span className="raw-response-controls">
              <Button
                bsSize="small"
                bsStyle="link"
                onClick={( ) => this.setState( { showAll: !showAll } )}
              >
                { showAll
                  ? `hide results (${resultCount} taxa)`
                  : `include results (${resultCount} taxa)` }
              </Button>
              <Button bsSize="small" bsStyle="link" onClick={( ) => this.copy( json )}>
                { copied ? "copied" : "copy" }
              </Button>
            </span>
          ) }
        </div>
        { expanded && <pre className="raw-response-json">{ json }</pre> }
      </div>
    );
  }
}

RawResponse.propTypes = {
  response: PropTypes.object
};

export default RawResponse;
