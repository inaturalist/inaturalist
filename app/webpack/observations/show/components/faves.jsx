import _ from "lodash";
import React, { PropTypes } from "react";
import UsersPopover from "./users_popover";

const Faves = ( { observation, config, fave, unfave } ) => {
  const loggedIn = config && config.currentUser && config.currentUser.id;
  if ( !observation || !loggedIn ) { return ( <div /> ); }
  let userHasFavedThis;
  let message;
  if ( observation.faves && observation.faves.length > 0 ) {
    userHasFavedThis = observation.faves && _.find( observation.faves, o => (
      o.user.id === config.currentUser.id
    ) );
    if ( observation.faves.length === 1 && userHasFavedThis ) {
      message = "You faved this!";
    } else {
      const favesToShow = [];
      const otherFaves = [];
      let others;
      _.each( observation.faves, ( f, index ) => {
        if ( index < 2 ) {
          favesToShow.push( f );
        } else {
          otherFaves.push( f );
        }
      } );
      if ( otherFaves.length > 0 ) {
        const text = (
          <span className="others">
            { observation.faves.length - 2 } others
          </span>
        );
        others = (
          <span key={ `fave-others-${observation.id}` }>
            , and&nbsp;
            <UsersPopover
              users={ otherFaves.map( f => ( f.user ) ) }
              keyPrefix="faves"
              contents={ text }
            />
          </span>
        );
      }
      message = (
        <span>
          { favesToShow.map( f => (
            <span key={ `fave-${f.id}` } className="user">
              <a href={ `/people/${f.user.login}` }>{ f.user.login }</a>
            </span>
          ) ) }
          { others }
          &nbsp;faved this observation
        </span>
      );
    }
  } else {
    message = "Be the first to fave this observation!";
  }
  const starIconClass = userHasFavedThis ? "fa-star" : "fa-star-o";
  const hoverStarIconClass = userHasFavedThis ? "fa-star-o" : "fa-star";
  const starIcon = (
    <i className={ `action fa ${starIconClass}` }
      onClick={ ( ) => {
        if ( userHasFavedThis ) {
          unfave( observation.id );
        } else {
          fave( observation.id );
        }
      } }
      onMouseOver={ e => {
        $( e.target ).removeClass( starIconClass );
        $( e.target ).addClass( hoverStarIconClass );
      } }
      onMouseOut={ e => {
        $( e.target ).removeClass( hoverStarIconClass );
        $( e.target ).addClass( starIconClass );
      } }
    />
  );
  return (
    <div className="Faves">
      { starIcon }
      { message }
    </div>
  );
};

Faves.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  fave: PropTypes.func,
  unfave: PropTypes.func
};

export default Faves;
