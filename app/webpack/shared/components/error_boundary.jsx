import React from "react";
import PropTypes from "prop-types";

// This is basically like a component version of try/catch that will show the
// user that something went wrong and log the error. See
// https://reactjs.org/docs/error-boundaries.html
//
// REALLY IMPORTANT: if you use multiple ErrorBoundaries on the same page, give
// them unique key attributes.
class ErrorBoundary extends React.Component {
  constructor( props ) {
    super( props );
    this.state = { error: null };
  }

  static getDerivedStateFromError( error ) {
    // Update state so the next render will show the fallback UI.
    return { error };
  }

  componentDidCatch( error ) {
    iNaturalist.logError( error );
  }

  render( ) {
    const { error } = this.state;
    const { renderError } = this.props;
    if ( error ) {
      if ( typeof ( renderError ) === "function" ) {
        return renderError( error );
      }
      return (
        <div className="nocontent alert alert-danger">
          { I18n.t( "doh_something_went_wrong_error", { error } ) }
        </div>
      );
    }
    // eslint-disable-next-line react/prop-types
    return this.props.children;
  }
}

ErrorBoundary.propTypes = {
  renderError: PropTypes.func
};

export default ErrorBoundary;
