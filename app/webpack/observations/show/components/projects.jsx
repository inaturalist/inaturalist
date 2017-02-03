import _ from "lodash";
import React, { PropTypes } from "react";

const Projects = ( { observation, config } ) => {
  if ( !observation ) { return ( <div /> ); }
  return (
    <div className="Projects">
      <h4>Projects</h4>
      {
        observation.project_observations.map( po => (
          <div className="project" key={ `project-${po.project.id}` }>
            <a href={ `/projects/${po.project.id}` }>
              <div className="image">
                <img src={po.project.icon} />
              </div>
              { po.project.title }
            </a>
          </div>
        ) )
      }
    </div>
  );
};

Projects.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object
};

export default Projects;
