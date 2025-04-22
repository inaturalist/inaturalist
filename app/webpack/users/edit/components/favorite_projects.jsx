import React from "react";
import PropTypes from "prop-types";

import FavoriteProject from "./favorite_project";

const FavoriteProjects = ( { favoriteProjects, updateFavedProjectIds } ) => {
  const [positions, setPositions] = React.useState( favoriteProjects.map( p => p.id ) );

  // update temp state when favoriteProjects actually updates
  React.useEffect( ( ) => {
    if ( JSON.stringify( positions ) !== JSON.stringify( favoriteProjects.map( p => p.id ) ) ) {
      setPositions( favoriteProjects.map( p => p.id ) );
    }
  }, [
    JSON.stringify( favoriteProjects.map( p => p.id ) )
  ] );

  return (
    <div className="FavoriteProjects">
      <h4>here are your favorite projects</h4>
      <ul>
        { positions.map( ( projectId, position ) => {
          const project = favoriteProjects.find( p => p.id === projectId );
          return (
            <FavoriteProject
              key={`fave-project-${project.id}`}
              position={position}
              onDrag={( oldPosition, newPosition ) => {
                const changedProjectId = positions[oldPosition];
                const newPositions = [...positions];
                newPositions.splice( oldPosition, 1 );
                newPositions.splice( newPosition, 0, changedProjectId );
                setPositions( newPositions );
              }}
              project={project}
              onChange={() => updateFavedProjectIds( positions )}
            />
          );
        } ) }
      </ul>
    </div>
  );
};

FavoriteProjects.propTypes = {
  favoriteProjects: PropTypes.arrayOf( PropTypes.shape( {
    id: PropTypes.number,
    title: PropTypes.string
  } ) ),
  updateFavedProjectIds: PropTypes.func
};

export default FavoriteProjects;
