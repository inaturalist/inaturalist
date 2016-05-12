import _ from "lodash";
import React, { Component, PropTypes } from "react";

class TopProjects extends Component {

  render( ) {
    let index = 0;
    let subProjects;
    let secondColumn;
    let className = "col-md-6";
    if ( this.props.project.id !== this.props.overallID &&
         this.props.umbrellaSubProjects[this.props.project.id] ) {
      subProjects = this.props.umbrellaSubProjects[this.props.project.id];
    } else {
      subProjects = this.props.allSubProjects;
    }
    subProjects = _.sortBy( subProjects, p => p.observation_count * -1 );
    const projects = _.map( subProjects.slice( 0, 20 ), p => {
      index += 1;
      return (
        <tr key={ `project${p.id}` }>
          <td className="index">{ index }</td>
          <td className="title">{ p.title }</td>
          <td className="observations">{ Number( p.observation_count ).toLocaleString( ) }</td>
          <td className="species">{ Number( p.species_count ).toLocaleString( ) }</td>
        </tr>
      );
    } );
    if ( projects.length > 10 ) {
      secondColumn = (
        <div className="col-md-6">
          <table className="table">
            <thead>
              <tr>
                <th>Rank</th>
                <th></th>
                <th>Obs.</th>
                <th>Species</th>
              </tr>
            </thead>
            <tbody>
              { projects.slice( 10, 20 ) }
            </tbody>
          </table>
        </div>
      );
    } else {
      className += " center";
    }
    return (
      <div className="slide top-projects-slide">
        <div className={ className }>
          <table className="table">
            <thead>
              <tr>
                <th>Rank</th>
                <th></th>
                <th>Obs.</th>
                <th>Species</th>
              </tr>
            </thead>
            <tbody>
              { projects.slice( 0, 10 ) }
            </tbody>
          </table>
        </div>
        { secondColumn }
      </div>
    );
  }
}

TopProjects.propTypes = {
  project: PropTypes.object,
  overallID: PropTypes.number,
  allSubProjects: PropTypes.array,
  umbrellaSubProjects: PropTypes.object
};

export default TopProjects;
