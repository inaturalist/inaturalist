import React, { Component, PropTypes } from "react";
import Slides from "./slides";
import moment from "moment";

class Slideshow extends Component {

  render( ) {
    let dateRange = "";
    if ( !this.props.project ) {
      return (
        <h1 className="noresults">
          No Project Selected
        </h1>
      );
    }
    if ( this.props.project.start_time && this.props.project.end_time ) {
      if ( this.props.project.in_progress ) {
        dateRange = I18n.t("in_progress");
      }
      const start = moment( this.props.project.start_time ).format( "M/D/YY" );
      const end = moment( this.props.project.end_time ).format( "M/D/YY" );
      if ( start === end ) {
        dateRange += `(${start})`;
      } else {
        dateRange += `(${start} - ${end})`;
      }
    }
    let logoPaths;
    if ( !this.props.singleProject ) {
      logoPaths = LOGO_PATHS;
    }
    return (
      <div id="main-container">
        <nav className="navbar">
          <div className="container-fluid">
            <div className="nav navbar-nav navbar-left">
              <a href="/">
                <img src="/logo-inat.svg" />
              </a>
            </div>
            <div className="nav navbar-nav navbar-title">
              <a href={ `/projects/${this.props.project.slug}` }>
                { this.props.project.title }
              </a>
              <span className="dates">
                { dateRange }
              </span>
            </div>
            { logoPaths ? logoPaths.map( path => (
              <div key={`logos-${path}`} className="nav navbar-nav navbar-right">
                <img src={path} />
              </div>
            ) ) : null }
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
  project: PropTypes.object,
  singleProject: PropTypes.object,
  setState: PropTypes.func
};

export default Slideshow;
