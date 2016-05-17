import React, { Component, PropTypes } from "react";
import Slides from "./slides";
import moment from "moment";

class Slideshow extends Component {

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
    let npsLogo;
    let natGeoLogo;
    if ( !this.props.singleProject ) {
      npsLogo = ( <img src="/logo-nps.svg" /> );
      natGeoLogo = ( <img src="/logo-natgeo.svg" /> );
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
            <div className="nav navbar-nav navbar-right">
              { npsLogo }
            </div>
            <div className="nav navbar-nav navbar-right natgeo">
              { natGeoLogo }
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
  project: PropTypes.object,
  singleProject: PropTypes.object,
  setState: PropTypes.func
};

export default Slideshow;
