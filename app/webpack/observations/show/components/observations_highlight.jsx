import _ from "lodash";
import React, { PropTypes } from "react";

const ObservationsHighlight = ( { title, observations, searchParams } ) => {
  if ( _.isEmpty( observations ) ) { return ( <div /> ); }
  return (
    <div className="ObservationsHighlight">
      <h3>
        { title }
        <a href={ `/observations?${$.param( searchParams )}` }>
          View all
        </a>
      </h3>
      <div className="list">
        { _.filter( observations, o => ( o.photo( ) ) ).map( o => (
          <div className="photo">
            <a
              href={ `/observations/${o.id}` }
              style={ { backgroundImage: `url( '${o.photo( "small" )}' )` } }
            />
          </div>
          ) )
        }
      </div>
    </div>
  );
};

ObservationsHighlight.propTypes = {
  title: PropTypes.string,
  searchParams: PropTypes.object,
  observations: PropTypes.array
};

export default ObservationsHighlight;
