import _ from "lodash";
import React, { PropTypes } from "react";
import { Dropdown, MenuItem, Glyphicon } from "react-bootstrap";
import UsersPopover from "./users_popover";
import UserImage from "../../identify/components/user_image";

class Annotations extends React.Component {
  render( ) {
    const observation = this.props.observation;
    const config = this.props.config;
    const controlledTerms = this.props.controlledTerms;
    if ( !observation ) { return ( <span /> ); }
    const loggedIn = config && config.currentUser;
    const viewerIsObserver = loggedIn && config.currentUser.id === observation.user.id;
    const groupedTerms = _.groupBy( observation.annotations, a => ( a.controlled_attribute.id ) );
    let rows = [];
    _.each( controlledTerms, ct => {
      if ( groupedTerms[ct.id] ) {
        _.each( groupedTerms[ct.id], gt => {
          let votersFor = [];
          let votersAgainst = [];
          let userVotedFor;
          let userVotedAgainst;
          _.each( gt.votes, v => {
            if ( v.vote_flag === true ) {
              votersFor.push( v.user );
            } else {
              votersAgainst.push( v.user );
            }
            if ( loggedIn && v.user.id === config.currentUser.id ) {
              userVotedFor = ( v.vote_flag === true );
              userVotedAgainst = ( v.vote_flag === false );
            }
          } );
          const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
          const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";
          const mostAgree = votersFor.length > votersAgainst.length;
          const mostDisagree = votersAgainst.length > votersFor.length;
          const viewerIsAnnotator = loggedIn && gt.user && config.currentUser.id === gt.user.id;
          const remove = viewerIsObserver || viewerIsAnnotator ? (
            <Glyphicon
              glyph="remove-circle"
              onClick={ () => { this.props.deleteAnnotation( gt.uuid ); } }
            />
          ) : null;
          rows.push( (
            <tr key={ `term-row-${gt.controlled_value.id}` }>
              <td className="attribute">{ ct.label }</td>
              <td className="value">
                <UserImage user={ gt.user } />
                { gt.controlled_value.label }
                { remove }
              </td>
              <td className="agree">
                <span className="check">
                  { mostAgree ? (
                    <i className="fa fa-check" />
                  ) : null }
                </span>
                <i className={ `fa ${agreeClass}` } onClick={ () => (
                  userVotedFor ?
                    this.props.unvoteAnnotation( gt.uuid ) :
                    this.props.voteAnnotation( gt.uuid ) ) }
                />
                <span className="count">
                  <UsersPopover
                    users={ votersFor }
                    keyPrefix={ `votes-for-${gt.controlled_value.id}` }
                    contents={ ( <span>({votersFor.length})</span> ) }
                  />
                </span>
              </td>
              <td className="disagree">
                <span className="check">
                  { mostDisagree ? (
                    <i className="fa fa-check" />
                  ) : null }
                </span>
                <i className={ `fa ${disagreeClass}` } onClick={ () => (
                  userVotedAgainst ?
                    this.props.unvoteAnnotation( gt.uuid ) :
                    this.props.voteAnnotation( gt.uuid, "bad" ) ) }
                />
                <span className="count">
                  <UsersPopover
                    users={ votersAgainst }
                    keyPrefix={ `votes-against-${gt.controlled_value.id}` }
                    contents={ ( <span>({votersAgainst.length})</span> ) }
                  />
                </span>
              </td>
            </tr>
          ) );
        } );
      }
      // TODO: filter terms by taxon ID
      let availableValues = ct.values;
      if ( groupedTerms[ct.id] && ct.multivalued ) {
        const usedValues = { };
        _.each( groupedTerms[ct.id], gt => { usedValues[gt.controlled_value.id] = true; } );
        availableValues = _.filter( availableValues, v => ( !usedValues[v.id] ) );
      }
      if ( observation.taxon ) {
        availableValues = _.filter( availableValues, v => (
          !v.valid_within_clade ||
          _.includes( observation.taxon.ancestor_ids, v.valid_within_clade )
        ) );
      }
      if ( availableValues.length > 0 &&
           !( groupedTerms[ct.id] && !ct.multivalued ) ) {
        rows.push( (
          <tr key={ `term-row-${ct.id}` }>
            <td className="attribute">{ ct.label }</td>
            <td>
              <Dropdown
                id="grouping-control"
                onSelect={ ( event, index ) => {
                  this.props.addAnnotation( ct, availableValues[index] );
                }}
              >
                <Dropdown.Toggle>
                  <span className="toggle">
                    Select
                  </span>
                </Dropdown.Toggle>
                <Dropdown.Menu className="dropdown-menu-right">
                  {
                    availableValues.map( ( v, index ) => (
                      <MenuItem
                        key={ `term-${v.id}` }
                        eventKey={ index }
                      >{ v.label }</MenuItem>
                    ) )
                  }
                </Dropdown.Menu>
              </Dropdown>
            </td>
            <td></td>
            <td></td>
          </tr>
        ) );
      }
    } );

    return (
      <div className="Annotations">
        <h4>Annotations</h4>
        <table className="table">
          <thead>
            <tr>
              <th>Attribute</th>
              <th>Value</th>
              <th>Agree</th>
              <th>Disagree</th>
            </tr>
          </thead>
          <tbody>
            { rows }
          </tbody>
        </table>
      </div>
    );
  }
}

Annotations.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  controlledTerms: PropTypes.array,
  addAnnotation: PropTypes.func,
  deleteAnnotation: PropTypes.func,
  voteAnnotation: PropTypes.func,
  unvoteAnnotation: PropTypes.func
};

export default Annotations;
