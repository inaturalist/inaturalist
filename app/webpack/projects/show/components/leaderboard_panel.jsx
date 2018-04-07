import _ from "lodash";
import React, { PropTypes } from "react";
import { numberWithCommas } from "../../../shared/util";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";
import util from "../../../observations/show/util";

class LeaderboardPanel extends React.Component {

  linkForRow( l ) {
    const { project, type } = this.props;
    const linkParams = Object.assign( { }, project.search_params );
    if ( type === "species" ) {
      linkParams.taxon_id = l.taxon.id;
    } else if ( type === "observers" ) {
      linkParams.user_id = l.user.id;
    } else if ( type === "species_observers" ) {
      linkParams.user_id = l.user.id;
      linkParams.hrank = "species";
      linkParams.view = "species";
    }
    return `/observations?${$.param( linkParams )}`;
  }

  linkForViewAll( ) {
    const { project, type } = this.props;
    const params = Object.assign( { }, project.search_params );
    if ( type === "species" ) {
      params.view = "species";
    } else if ( type === "observers" ) {
      params.view = "observers";
    } else if ( type === "species_observers" ) {
      params.view = "observers";
    }
    return `/observations?${$.param( params )}`;
  }

  render( ) {
    const { config, type, leaders } = this.props;
    if ( _.isEmpty( leaders ) ) { return ( <div /> ); }
    const leader = leaders[0];
    let countAttribute = "count";
    let title = I18n.t( "most_observed_species" );
    if ( type === "observers" ) {
      countAttribute = "observation_count";
      title = I18n.t( "most_observations" );
    } else if ( type === "species_observers" ) {
      countAttribute = "species_count";
      title = I18n.t( "most_species" );
    }
    return (
      <div className={ `LeaderboardPanel ${type}` }>
        <div className="leader">
          <div className="icon">
            { leader.user ?
              ( <UserImage user={ leader.user } /> ) :
              util.taxonImage( leader.taxon )
            }
            { leader.user && ( <div className="ribbon-container">
              <a href={ `/users/${leader.user.id}` }>
                <div className="ribbon">
                  <div className="ribbon-content">
                    { "1st" }
                  </div>
                </div>
              </a>
            </div> )
          }
          </div>
          <div className="leader-header">
            <div className="leaderboard-title">{ title }</div>
            <div className="leader-row">
              <div className="leader-label">
                { leader.user ?
                  ( <UserLink user={ leader.user } /> ) :
                  <SplitTaxon
                    taxon={ leader.taxon }
                    url={ `/taxa/${leader.taxon.id}` }
                    user={ config.currentUser }
                  />
                }
              </div>
              <div className="leader-count">
                <a href={ this.linkForRow( leader ) }>
                  { numberWithCommas( leader[countAttribute] ) }
                </a>
              </div>
            </div>
          </div>
        </div>
        <table>
          <tbody>
            { leaders.slice( 1, 6 ).map( l => (
              <tr key={ `${type}-leader-${l.user ? l.user.id : l.taxon.id}` }>
                <td className="leader-name">
                  { l.user ? ( <UserImage user={ l.user } /> ) : util.taxonImage( l.taxon ) }
                  { l.user ?
                    ( <UserLink user={ l.user } /> ) :
                    <SplitTaxon
                      taxon={ l.taxon }
                      url={ `/taxa/${l.taxon.id}` }
                      user={ config.currentUser }
                    />
                  }
                </td>
                <td className="leader-count">
                  <a href={ this.linkForRow( l ) }>
                    { numberWithCommas( l[countAttribute] ) }
                  </a>
                </td>
              </tr>
            ) ) }
          </tbody>
        </table>
        <a href={ this.linkForViewAll( ) }>
          <button className="btn-green" >
            { I18n.t( "view_all" ) }
          </button>
        </a>
        <a href={ this.linkForViewAll( ) }>
          <button className="btn-white">
            { I18n.t( "view_yours" ) }
          </button>
        </a>
      </div>
    );
  }
}

LeaderboardPanel.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leaders: PropTypes.array,
  type: PropTypes.string
};

export default LeaderboardPanel;
