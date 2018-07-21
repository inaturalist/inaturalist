import React, { Component } from "react";
import PropTypes from "prop-types";
import Slides from "./slides";

class Slideshow extends Component {

  render( ) {
    if ( Object.keys( this.props.searchParams ).length === 0 ) {
      return (
        <h1 className="noresults">
          No Params
        </h1>
      );
    }
    return (
      <div id="main-container">
        <nav className="navbar">
          <div className="container-fluid">
            <div className="nav navbar-nav navbar-left">
              <a href="/">
                <img src="/logo.plain.svg" />
              </a>
            </div>
            <div className="nav navbar-nav navbar-title">
              <a href={ `/observations?${$.param( this.props.searchParams )}` }>
                { this.props.title }
              </a>
              <span className="dates">
                { this.props.subtitle }
              </span>
            </div>
          </div>
        </nav>
        <div className="container-fluid content">
          <Slides { ...this.props } />
        </div>
      </div>
    );
  }
}

Slideshow.propTypes = {
  searchParams: PropTypes.object,
  setState: PropTypes.func,
  subtitle: PropTypes.string,
  title: PropTypes.string
};

export default Slideshow;
