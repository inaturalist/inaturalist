import _ from "lodash";
import React, { PropTypes } from "react";
import colors from "../umbrella_project_colors";

const UmbrellaLeaderboard = ( { project, setConfig, config } ) => {
  const projectStats = project.umbrella_stats_loaded ? project.umbrella_stats.results : [];
  if ( _.isEmpty( projectStats ) ) { return ( <span /> ); }
  const limit = config.umbrellaLeaderboardLimit || 8;
  const sort = config.umbrellaLeaderboardSort || "observations";
  let sortField = "observation_count";
  if ( sort === "species" ) {
    sortField = "species_count";
  } else if ( sort === "observers" ) {
    sortField = "observers_count";
  }
  const projectColors = _.fromPairs( _.map( project.umbrella_stats.results, ( ps, index ) =>
    [ps.project.id, colors[index % colors.length]]
  ) );
  const sortedProjectStats = _.reverse( _.sortBy( projectStats, sortField ) );
  const maximumCount = Number( sortedProjectStats[0][sortField] );
  const showMore = sortedProjectStats.length > limit;
  return (
    <div className="UmbrellaLeaderboard">
      <h2>{ I18n.t( "leaderboard" ) }</h2>
      <div className="sort">
        { `${I18n.t( "sort_by" )}:` }
        <span
          className={ `sort-option ${sort === "observations" && "active"}` }
          onClick={ () => setConfig(
            { umbrellaLeaderboardSort: "observations", umbrellaLeaderboardLimit: 8 } ) }
        >
          { I18n.t( "observations" ) }
        </span> |
        <span
          className={ `sort-option ${sort === "species" && "active"}` }
          onClick={ () => setConfig(
            { umbrellaLeaderboardSort: "species", umbrellaLeaderboardLimit: 8 } ) }
        >
          { I18n.t( "species" ) }
        </span> |
        <span
          className={ `sort-option ${sort === "observers" && "active"}` }
          onClick={ () => setConfig(
            { umbrellaLeaderboardSort: "observers", umbrellaLeaderboardLimit: 8 } ) }
        >
          { I18n.t( "observers" ) }
        </span>
      </div>
      <div className="leaders-panel">
        <table>
          <tbody>
            { _.map( sortedProjectStats.slice( 0, limit ), ps => {
              const width = Math.floor( ( Number( ps[sortField] ) / maximumCount ) * 100 );
              const color = projectColors[ps.project.id];
              return (
                <tr className="leader-row" key={ `umbrella_${ps.project.id}_${sortField}` }>
                  <td className="icon-cell">
                    <a href={ `/projects/${ps.project.slug}` }>
                      { !ps.project.icon || ps.project.icon.match( "attachment_defaults" ) ? (
                        <i className="fa fa-briefcase leader-icon" />
                      ) : (
                        <div
                          className="leader-icon"
                          style={ { backgroundImage: `url( '${ps.project.icon}' )` } }
                        />
                      ) }
                    </a>
                  </td>
                  <td className="leader-data">
                    <a href={ `/projects/${ps.project.slug}` }>
                      <div className="leader-score">
                        { width > 0 && (
                          <div
                            className="leader-bar"
                            style={ { width: `${width}%`, background: color } }
                          />
                        ) }
                        <div className="leader-count" style={ { color } }>
                          { I18n.toNumber( ps[sortField], { precision: 0 } ) }
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
            { I18n.t( "view_more" ) }
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
