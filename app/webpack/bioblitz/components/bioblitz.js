import React, { Component, PropTypes } from "react";
import Slideshow from "./slideshow";
import moment from "moment";

class Bioblitz extends Component {

  render( ) {
    let dateRange = "";
    if ( this.props.project.start_time && this.props.project.end_time ) {
      if ( this.props.project.in_progress ) {
        dateRange = "In progress ";
      }
      const start = moment( this.props.project.start_time ).format( "M/D/YY" );
      const end = moment( this.props.project.end_time ).format( "M/D/YY" );
      dateRange += `(${start} - ${end})`;
    }
    return (
      <div id="main-container">
        <nav className="navbar">
          <div className="container-fluid">
            <div className="nav navbar-nav navbar-left">
              <img src="/logo-inat.svg" />
            </div>
            <div className="nav navbar-nav navbar-title">
              { this.props.project.title }
              <span className="dates">
                { dateRange }
              </span>
            </div>
            <div className="nav navbar-nav navbar-right">
              <img src="/logo-nps.svg" />
            </div>
          </div>
        </nav>
        <div className="container-fluid content">
          <Slideshow { ...this.props } />
        </div>
      </div>
    );
  }
}

Bioblitz.propTypes = {
  project: PropTypes.object,
  setState: PropTypes.func
};

export default Bioblitz;
