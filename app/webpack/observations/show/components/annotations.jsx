import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  Dropdown, MenuItem, OverlayTrigger, Popover, Panel
} from "react-bootstrap";
import UsersPopover from "./users_popover";
import UserImage from "../../../shared/components/user_image";
import { termsForTaxon } from "../ducks/controlled_terms";

class Annotations extends React.Component {
  componentDidMount( ) {
    this.fetchAnnotations( );
  }

  componentDidUpdate( prevProps ) {
    if ( prevProps.open !== this.props.open ) {
      this.fetchAnnotations( );
    }
  }

  fetchAnnotations( ) {
    const {
      fetchControlledTerms,
      open: isOpen,
      updateSession,
      config,
      collapsible
    } = this.props;
    if ( collapsible && this.loggedIn
      // if user closes the panel, set in preferences that they prefer to hide the panel
      // if user opens the panel, set in preferences that they don't prefer to hide the panel
      // only update if the current user setting is different from the new panel state
      && ( config.currentUser.prefers_hide_obs_show_annotations !== !isOpen )
    ) {
      updateSession( { prefers_hide_obs_show_annotations: !isOpen } );
    }
    if ( isOpen ) {
      fetchControlledTerms( );
    }
  }

  annotationRow( a, term ) {
    const votersFor = [];
    const votersAgainst = [];
    const {
      config,
      deleteAnnotation,
      voteAnnotation,
      unvoteAnnotation
    } = this.props;
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
      if ( this.loggedIn && v.user.id === config.currentUser.id ) {
        userVotedFor = ( v.vote_flag === true );
        userVotedAgainst = ( v.vote_flag === false );
      }
    } );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";
    const mostAgree = votersFor.length > votersAgainst.length;
    const mostDisagree = votersAgainst.length > votersFor.length;
    const viewerIsAnnotator = this.loggedIn && a.user
      && config.currentUser.id === a.user.id;
    let action;
    if ( a.api_status && a.api_status !== "voting" ) {
      action = ( <div className="loading_spinner" /> );
    } else if ( this.viewerIsObserver || viewerIsAnnotator ) {
      action = (
        <button
          type="button"
          className="btn btn-nostyle"
          onClick={() => {
            if ( a.api_status ) { return; }
            deleteAnnotation( a.uuid );
          }}
        >
          <i className="glyphicon glyphicon-remove-circle" />
        </button>
      );
    }
    let voteAction;
    let unvoteAction;
    if ( !a.api_status ) {
      voteAction = () => ( userVotedFor ? unvoteAnnotation( a.uuid ) : voteAnnotation( a.uuid ) );
      unvoteAction = () => ( userVotedAgainst ? unvoteAnnotation( a.uuid ) : voteAnnotation( a.uuid, "bad" ) );
    }
    const votesForCount = voteForLoading ? (
      <div className="loading_spinner" />
    ) : (
      <UsersPopover
        users={votersFor}
        keyPrefix={`votes-for-${a.controlled_value.id}`}
        contents={( <span>{votersFor.length === 0 ? null : votersFor.length}</span> )}
      />
    );
    const votesAgainstCount = voteAgainstLoading ? (
      <div className="loading_spinner" />
    ) : (
      <UsersPopover
        users={votersAgainst}
        keyPrefix={`votes-against-${a.controlled_value.id}`}
        contents={( <span>{votersAgainst.length === 0 ? null : votersAgainst.length}</span> )}
      />
    );
    const attr = a.controlled_attribute;
    const value = a.controlled_value;
    const termLabel = I18n.t( `controlled_term_labels.${_.snakeCase( term.label )}` );
    const attrLabel = I18n.t( `controlled_term_labels.${_.snakeCase( attr.label )}` );
    const valueLabel = I18n.t( `controlled_term_labels.${_.snakeCase( value.label )}` );
    const termDefinition = I18n.t( `controlled_term_definitions.${_.snakeCase( term.label )}` );
    const valueDefinition = I18n.t( `controlled_term_definitions.${_.snakeCase( value.label )}` );
    const termPopover = (
      <Popover
        id={`annotation-popover-${a.uuid}`}
        className="AnnotationPopover"
      >
        <div className="contents">
          { termDefinition && !termDefinition.match( /\[missing/ ) && <p>{ termDefinition }</p> }
          <div className="view">{ I18n.t( "label_colon", { label: I18n.t( "view" ) } ) }</div>
          <div className="search">
            <a href={`/observations?term_id=${attr.id}&term_value_id=${value.id}`}>
              <i className="fa fa-arrow-circle-o-right" />
              { I18n.t( "observations_annotated_with_annotation", {
                annotation: `${attrLabel}: ${valueLabel}`
              } ) }
            </a>
          </div>
          <div className="search">
            <a href={`/observations?term_id=${attr.id}`}>
              <i className="fa fa-arrow-circle-o-right" />
              { I18n.t( "observations_annotated_with_annotation", { annotation: attrLabel } ) }
            </a>
          </div>
        </div>
      </Popover>
    );
    return (
      <tr
        key={`term-row-${value.id}`}
        className={a.api_status ? "disabled" : ""}
      >
        <td className="attribute">
          <OverlayTrigger
            trigger="click"
            rootClose
            placement="top"
            animation={false}
            overlay={termPopover}
          >
            <div>{ termLabel }</div>
          </OverlayTrigger>
        </td>
        <td className="value">
          <UserImage user={a.user} />
          <span title={valueDefinition}>
            { valueLabel }
          </span>
          { action }
        </td>
        <td className="agree">
          <span className="check">
            { mostAgree ? (
              <i className="fa fa-check" />
            ) : null }
          </span>
          { this.loggedIn && (
            <button type="button" className="btn btn-nostyle" onClick={voteAction}>
              <i className={`fa ${agreeClass}`} />
            </button>
          ) }
          <span className="count">{ votesForCount }</span>
          { !this.loggedIn && <span className="fa" /> }
        </td>
        <td className="disagree">
          <span className="check">
            { mostDisagree ? (
              <i className="fa fa-times" />
            ) : null }
          </span>
          { this.loggedIn && (
            <button
              type="button"
              onClick={unvoteAction}
              className="btn btn-nostyle"
            >
              <i className={`fa ${disagreeClass}`} />
            </button>
          ) }
          <span className="count">{ votesAgainstCount }</span>
          { !this.loggedIn && <span className="fa" /> }
        </td>
      </tr>
    );
  }

  render( ) {
    const {
      observation,
      config,
      controlledTerms,
      addAnnotation,
      collapsible,
      loading,
      open: isOpen,
      showAnnotationsPanel
    } = this.props;
    const observationAnnotations = observation.annotations || [];
    const availableControlledTerms = termsForTaxon(
      controlledTerms,
      observation ? observation.taxon : null
    );
    if ( !observation || !observation.user ) {
      return ( <span /> );
    }
    this.loggedIn = config && config.currentUser;
    this.viewerIsObserver = this.loggedIn && config.currentUser.id === observation.user.id;
    if ( !this.loggedIn && _.isEmpty( observationAnnotations ) ) {
      return ( <span /> );
    }
    const annotations = _.filter(
      observationAnnotations,
      a => a.controlled_attribute && a.controlled_value
    );
    const groupedAnnotations = _.groupBy( annotations, a => a.controlled_attribute.id );
    const rows = [];
    _.each( availableControlledTerms, ct => {
      if ( groupedAnnotations[ct.id] ) {
        const sorted = _.sortBy( groupedAnnotations[ct.id], a => (
          I18n.t( `controlled_term_labels.${_.snakeCase( a.controlled_value.label )}`, {
            defaultValue: a.controlled_value.label
          } )
        ) );
        _.each( sorted, a => {
          rows.push( this.annotationRow( a, ct ) );
        } );
      }
      let availableValues = ct.values;
      if ( groupedAnnotations[ct.id] && ct.multivalued ) {
        const usedValues = { };
        _.each(
          groupedAnnotations[ct.id],
          gt => { usedValues[gt.controlled_value.id] = gt.controlled_value; }
        );
        availableValues = _.filter( availableValues, v => ( !usedValues[v.id] ) );
        // If values have already been used, we should not allow the addition of blocking values
        if ( !_.isEmpty( usedValues ) ) {
          const usedBlockingValue = _.find( usedValues, v => v.blocking );
          // If there's already a blocking value, no other values should be allowed.
          if ( usedBlockingValue ) {
            availableValues = [];
          } else {
            availableValues = _.filter( availableValues, v => !v.blocking );
          }
        }
      }
      if ( observation.taxon ) {
        availableValues = termsForTaxon( availableValues, observation ? observation.taxon : null );
      }
      const ctLabel = I18n.t( `controlled_term_labels.${_.snakeCase( ct.label )}`, {
        defaultValue: ct.label
      } );
      const termPopover = (
        <Popover
          id={`annotation-popover-${ct.id}`}
          className="AnnotationPopover"
        >
          <div className="contents">
            <div className="view">{ I18n.t( "label_colon", { label: I18n.t( "view" ) } ) }</div>
            <div className="search">
              <a href={`/observations?term_id=${ct.id}`}>
                <i className="fa fa-arrow-circle-o-right" />
                { I18n.t( "observations_annotated_with_annotation", { annotation: ctLabel } ) }
              </a>
            </div>
          </div>
        </Popover>
      );
      if (
        this.loggedIn
        && availableValues.length > 0
        && !( groupedAnnotations[ct.id] && !ct.multivalued )
      ) {
        rows.push( (
          <tr
            key={`term-row-${ct.id}`}
          >
            <td className="attribute">
              <OverlayTrigger
                trigger="click"
                rootClose
                placement="top"
                animation={false}
                overlay={termPopover}
              >
                <div>{ ctLabel }</div>
              </OverlayTrigger>
            </td>
            <td>
              <Dropdown
                id="grouping-control"
                onSelect={index => {
                  addAnnotation( ct, availableValues[index] );
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
                        key={`term-${v.id}`}
                        eventKey={index}
                        title={
                          I18n.t( `controlled_term_definitions.${_.snakeCase( v.label )}`, {
                            defaultValue: I18n.t( `controlled_term_labels.${_.snakeCase( v.label )}`, {
                              defaultValue: v.label
                            } )
                          } )
                        }
                      >
                        {
                          I18n.t( `controlled_term_labels.${_.snakeCase( v.label )}`, {
                            defaultValue: v.label
                          } )
                        }
                      </MenuItem>
                    ) )
                  }
                </Dropdown.Menu>
              </Dropdown>
            </td>
            <td />
            <td />
          </tr>
        ) );
      }
    } );

    const emptyState = (
      <div className="noresults">
        { loading ? I18n.t( "loading" ) : I18n.t( "no_relevant_annotations" ) }
      </div>
    );

    const table = (
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
    );

    if ( !collapsible ) {
      return (
        <div className="Annotations">
          { table }
        </div>
      );
    }

    const count = observationAnnotations.length > 0 ? `(${observationAnnotations.length})` : "";
    return (
      <div className="Annotations collapsible-section">
        <h4 className="collapsible">
          <button
            type="button"
            onClick={( ) => showAnnotationsPanel( !isOpen )}
            className="btn btn-nostyle"
          >
            <i className={`fa fa-chevron-circle-${isOpen ? "down" : "right"}`} />
            { I18n.t( "annotations" ) }
            { " " }
            { count }
          </button>
        </h4>
        <Panel expanded={isOpen} onToggle={() => {}}>
          <Panel.Collapse>
            {!availableControlledTerms || availableControlledTerms.length === 0
              ? emptyState
              : table}
          </Panel.Collapse>
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
  updateSession: PropTypes.func.isRequired,
  collapsible: PropTypes.bool,
  fetchControlledTerms: PropTypes.func,
  loading: PropTypes.bool,
  open: PropTypes.bool,
  showAnnotationsPanel: PropTypes.func
};

Annotations.defaultProps = {
  collapsible: true
};

export default Annotations;
