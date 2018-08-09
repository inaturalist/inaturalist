import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import UsersPopover from "./users_popover";

const Faves = ( { observation, config, fave, unfave, faveText, hideOtherUsers } ) => {
  const loggedIn = config && config.currentUser && config.currentUser.id;
  if ( !observation || !loggedIn ) { return ( <div /> ); }
  const userHasFavedThis = observation.faves && _.find( observation.faves, o => (
    o.user.id === config.currentUser.id
  ) );
  const starIconClass = userHasFavedThis ? "fa-star" : "fa-star-o";
  const hoverStarIconClass = userHasFavedThis ? "fa-star-o" : "fa-star";
  const FaveToggle = ( { text, className } ) => (
    <a
      href="#"
      className={ className }
      onClick={ ( ) => {
        if ( userHasFavedThis ) {
          unfave( observation.id );
        } else {
          fave( observation.id );
        }
        return false;
      } }
      onMouseOver={ e => {
        $( e.target ).siblings( "i" ).removeClass( starIconClass );
        $( e.target ).siblings( "i" ).addClass( hoverStarIconClass );
      } }
      onMouseOut={ e => {
        $( e.target ).siblings( "i" ).removeClass( hoverStarIconClass );
        $( e.target ).siblings( "i" ).addClass( starIconClass );
      } }
    >
      { text }
    </a>
  );
  let message = <FaveToggle text={ faveText } />;
  if ( observation.faves && observation.faves.length > 0 ) {
    if ( ( hideOtherUsers || observation.faves.length === 1 ) && userHasFavedThis ) {
      message = <FaveToggle text={ I18n.t( "you_faved_this" ) } />;
    } else if ( !hideOtherUsers ) {
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
            { I18n.t( "x_others", { count: observation.faves.length - 2 } ) }
          </span>
        );
        others = (
          <span key={ `fave-others-${observation.id}` }>
            , { I18n.t( "and" ) } <UsersPopover
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
          { others }&nbsp;
          { I18n.t( "faved_this_observation" ) }
        </span>
      );
    }
  }
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
  unfave: PropTypes.func,
  faveText: PropTypes.string,
  hideOtherUsers: PropTypes.bool
};

Faves.defaultProps = {
  faveText: I18n.t( "be_the_first_to_fave_this_observation" )
};

export default Faves;
