import React from "react";
import PropTypes from "prop-types";

const FavoriteProjects = ( { favoriteProjects } ) => (
  <div className="FavoriteProjects">
    <h4>here are your favorite projects</h4>
    <ul>
      { favoriteProjects.map( project => (
        <li key={`fave-project-${project.id}`}>
          { project.title }
        </li>
      ) ) }
    </ul>
  </div>
);

FavoriteProjects.propTypes = {
  favoriteProjects: PropTypes.arrayOf( PropTypes.shape( {
    id: PropTypes.number,
    title: PropTypes.string
  } ) )
};

export default FavoriteProjects;
