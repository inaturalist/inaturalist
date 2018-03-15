import _ from "lodash";
import React, { PropTypes } from "react";

const UmbrellaLeaderboard = ( { project, setConfig, config } ) => {
  const projectStats = project.umbrella_stats_loaded ? project.umbrella_stats.results : [];
  if ( _.isEmpty( projectStats ) ) { return ( <span /> ); }
  const colors = ["#127faa", "#75aa1f", "#1aaba3", "#aa17a3", "#f3474a", "#ce5abe", "#425cca"];
  const limit = config.umbrellaLeaderboardLimit || 8;
  const sort = config.umbrellaLeaderboardSort || "observations";
  let sortField = "observation_count";
  if ( sort === "species" ) {
    sortField = "species_count";
  } else if ( sort === "observers" ) {
    sortField = "observers_count";
  }
  const sortedProjectStats = _.reverse( _.sortBy( projectStats, sortField ) );
  const maximumCount = Number( sortedProjectStats[0][sortField] );
  const showMore = sortedProjectStats.length > limit;
  return (
    <div className="UmbrellaLeaderboard">
      <h2>Leaderboard</h2>
      <div className="sort">
        Sort by:
        <span
          className={ `sort-option ${sort === "observations" && "active"}` }
          onClick={ () => setConfig(
            { umbrellaLeaderboardSort: "observations", umbrellaLeaderboardLimit: 8 } ) }
        >
          Observations
        </span> |
        <span
          className={ `sort-option ${sort === "species" && "active"}` }
          onClick={ () => setConfig(
            { umbrellaLeaderboardSort: "species", umbrellaLeaderboardLimit: 8 } ) }
        >
          Species
        </span> |
        <span
          className={ `sort-option ${sort === "observers" && "active"}` }
          onClick={ () => setConfig(
            { umbrellaLeaderboardSort: "observers", umbrellaLeaderboardLimit: 8 } ) }
        >
          Observers
        </span>
      </div>
      <div className="leaders-panel">
        <table>
          <tbody>
            { _.map( sortedProjectStats.slice( 0, limit ), ( ps, index ) => {
              const width = ( Number( ps[sortField] ) / maximumCount ) * 100;
              const color = colors[index % colors.length];
              return (
                <tr className="leader-row" key={ `umbrella_${ps.project.id}_${sortField}` }>
                  <td className="icon-cell">
                    <a href={ `/projects/${ps.project.slug}` }>
                      <div
                        className="leader-icon"
                        style={ { backgroundImage: `url( '${ps.project.icon}' )` } }
                      />
                    </a>
                  </td>
                  <td className="leader-data">
                    <a href={ `/projects/${ps.project.slug}` }>
                      <div className="leader-score">
                        <div
                          className="leader-bar"
                          style={ { width: `${width}%`, background: color } }
                        />
                        <div className="leader-count" style={ { color } }>
                          { ps[sortField] }
                        </div>
                      </div>
                      <div className="leader-title">
                        { ps.project.title }
                      </div>
                    </a>
                  </td>
                </tr>
              );
            } ) }
          </tbody>
        </table>
        { showMore && (
          <div
            className="show-more"
            onClick={ ( ) => setConfig( { umbrellaLeaderboardLimit: sortedProjectStats.length } ) }
          >
            View More
            <i className="fa fa-arrow-circle-o-down" />
          </div>
        ) }
      </div>
    </div>
  );
};

UmbrellaLeaderboard.propTypes = {
  setConfig: PropTypes.func,
  project: PropTypes.object,
  config: PropTypes.object
};

export default UmbrellaLeaderboard;
