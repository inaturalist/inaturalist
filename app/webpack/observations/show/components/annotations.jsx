import _ from "lodash";
import React, { PropTypes } from "react";
import { Dropdown, MenuItem, Glyphicon, OverlayTrigger, Popover, Panel } from "react-bootstrap";
import UsersPopover from "./users_popover";
import UserImage from "../../identify/components/user_image";

class Annotations extends React.Component {

  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_annotations : true
    };
  }

  annotationRow( a, term ) {
    let votersFor = [];
    let votersAgainst = [];
    let userVotedFor;
    let userVotedAgainst;
    let voteForLoading;
    let voteAgainstLoading;
    _.each( a.votes, v => {
      if ( v.vote_flag === true ) {
        votersFor.push( v.user );
        if ( v.api_status ) { voteForLoading = true; }
      } else {
        votersAgainst.push( v.user );
        if ( v.api_status ) { voteAgainstLoading = true; }
      }
      if ( this.loggedIn && v.user.id === this.props.config.currentUser.id ) {
        userVotedFor = ( v.vote_flag === true );
        userVotedAgainst = ( v.vote_flag === false );
      }
    } );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";
    const mostAgree = votersFor.length > votersAgainst.length;
    const mostDisagree = votersAgainst.length > votersFor.length;
    const viewerIsAnnotator = this.loggedIn && a.user &&
      this.props.config.currentUser.id === a.user.id;
    let action;
    if ( a.api_status && a.api_status !== "voting" ) {
      action = ( <div className="loading_spinner" /> );
    } else if ( this.viewerIsObserver || viewerIsAnnotator ) {
      action = (
        <Glyphicon
          glyph="remove-circle"
          onClick={ () => {
            if ( a.api_status ) { return; }
            this.props.deleteAnnotation( a.uuid );
          } }
        />
      );
    }
    let voteAction;
    let unvoteAction;
    if ( !a.api_status ) {
      voteAction = () => ( userVotedFor ?
        this.props.unvoteAnnotation( a.uuid ) :
        this.props.voteAnnotation( a.uuid ) );
      unvoteAction = () => ( userVotedAgainst ?
        this.props.unvoteAnnotation( a.uuid ) :
        this.props.voteAnnotation( a.uuid, "bad" ) );
    }
    let votesForCount = voteForLoading ? (
      <div className="loading_spinner" /> ) : (
      <UsersPopover
        users={ votersFor }
        keyPrefix={ `votes-for-${a.controlled_value.id}` }
        contents={ ( <span>{votersFor.length}</span> ) }
      /> );
    let votesAgainstCount = voteAgainstLoading ? (
      <div className="loading_spinner" /> ) : (
      <UsersPopover
        users={ votersAgainst }
        keyPrefix={ `votes-against-${a.controlled_value.id}` }
        contents={ ( <span>{votersAgainst.length}</span> ) }
      /> );
    const attr = a.controlled_attribute;
    const value = a.controlled_value;
    const termPopover = (
      <Popover
        id={ `annotation-popover-${a.uuid}` }
        className="AnnotationPopover"
      >
        <div className="contents">
          <div className="view">{ I18n.t( "view" ) }:</div>
          <div className="search">
            <a href={ `/observations?term_id=${attr.id}&term_value_id=${value.id}` }>
              <i className="fa fa-arrow-circle-o-right" />
              { I18n.t( "observations_annotated_with_annotation", { annotation:
                `${attr.label}: ${value.label}` } ) }
            </a>
          </div>
          <div className="search">
            <a href={ `/observations?term_id=${attr.id}` }>
              <i className="fa fa-arrow-circle-o-right" />
              { I18n.t( "observations_annotated_with_annotation", { annotation: attr.label } ) }
            </a>
          </div>
        </div>
      </Popover>
    );
    return (
      <tr
        key={ `term-row-${value.id}` }
        className={ a.api_status ? "disabled" : "" }
      >
        <td className="attribute">
          <OverlayTrigger
            trigger="click"
            rootClose
            placement="top"
            animation={false}
            overlay={termPopover}
          >
            <div>{ term.label }</div>
          </OverlayTrigger>
        </td>
        <td className="value">
          <UserImage user={ a.user } />
          { value.label }
          { action }
        </td>
        <td className="agree">
          <span className="check">
            { mostAgree ? (
              <i className="fa fa-check" />
            ) : null }
          </span>
          <i className={ `fa ${agreeClass}` } onClick={ voteAction } />
          <span className="count">{ votesForCount }</span>
        </td>
        <td className="disagree">
          <span className="check">
            { mostDisagree ? (
              <i className="fa fa-check" />
            ) : null }
          </span>
          <i className={ `fa ${disagreeClass}` } onClick={ unvoteAction } />
          <span className="count">{ votesAgainstCount }</span>
        </td>
      </tr>
    );
  }

  render( ) {
    const observation = this.props.observation;
    const config = this.props.config;
    const controlledTerms = this.props.controlledTerms;
    if ( !observation || !observation.user || _.isEmpty( controlledTerms ) ) {
      return ( <span /> );
    }
    this.loggedIn = config && config.currentUser;
    this.viewerIsObserver = this.loggedIn && config.currentUser.id === observation.user.id;
    const groupedAnnotations = _.groupBy( observation.annotations, a => (
      a.controlled_attribute.id ) );
    let rows = [];
    _.each( controlledTerms, ct => {
      if ( groupedAnnotations[ct.id] ) {
        const sorted = _.sortBy( groupedAnnotations[ct.id], a => (
          a.controlled_value.label
        ) );
        _.each( sorted, a => {
          rows.push( this.annotationRow( a, ct ) );
        } );
      }
      // TODO: filter terms by taxon ID
      let availableValues = ct.values;
      if ( groupedAnnotations[ct.id] && ct.multivalued ) {
        const usedValues = { };
        _.each( groupedAnnotations[ct.id], gt => { usedValues[gt.controlled_value.id] = true; } );
        availableValues = _.filter( availableValues, v => ( !usedValues[v.id] ) );
      }
      if ( observation.taxon ) {
        availableValues = _.filter( availableValues, v => (
          !v.valid_within_clade ||
          _.includes( observation.taxon.ancestor_ids, v.valid_within_clade )
        ) );
      }
      const termPopover = (
        <Popover
          id={ `annotation-popover-${ct.id}` }
          className="AnnotationPopover"
        >
          <div className="contents">
            <div className="view">View:</div>
            <div className="search">
              <a href={ `/observations?term_id=${ct.id}` }>
                <i className="fa fa-arrow-circle-o-right" />
                { I18n.t( "observations_annotated_with_annotation", { annotation: ct.label } ) }
              </a>
            </div>
          </div>
        </Popover>
      );
      if ( availableValues.length > 0 &&
           !( groupedAnnotations[ct.id] && !ct.multivalued ) ) {
        rows.push( (
          <tr
            key={ `term-row-${ct.id}` }
          >
            <td className="attribute">
              <OverlayTrigger
                trigger="click"
                rootClose
                placement="top"
                animation={false}
                overlay={termPopover}
              >
                <div>{ ct.label }</div>
              </OverlayTrigger>
            </td>
            <td>
              <Dropdown
                id="grouping-control"
                onSelect={ ( event, index ) => {
                  this.props.addAnnotation( ct, availableValues[index] );
                }}
              >
                <Dropdown.Toggle>
                  <span className="toggle">
                    { I18n.t( "select" ) }
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

    const count = observation.annotations.length > 0 ?
      `(${observation.annotations.length})` : "";
    return (
      <div className="Annotations">
        <h4
          className="collapsable"
          onClick={ ( ) => {
            if ( this.loggedIn ) {
              this.props.updateSession( {
                prefers_hide_obs_show_annotations: this.state.open } );
            }
            this.setState( { open: !this.state.open } );
          } }
        >
          <i className={ `fa fa-chevron-circle-${this.state.open ? "down" : "right"}` } />
          { I18n.t( "annotations" ) } { count }
        </h4>
        <Panel collapsible expanded={ this.state.open }>
          <table className="table">
            <thead>
              <tr>
                <th>{ I18n.t( "attribute" ) }</th>
                <th>{ I18n.t( "value" ) }</th>
                <th>{ I18n.t( "agree_" ) }</th>
                <th>{ I18n.t( "disagree_" ) }</th>
              </tr>
            </thead>
            <tbody>
              { rows }
            </tbody>
          </table>
        </Panel>
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
  unvoteAnnotation: PropTypes.func,
  updateSession: PropTypes.func
};

export default Annotations;
