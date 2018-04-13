import React, { PropTypes } from "react";
import _ from "lodash";
import { Popover, OverlayTrigger } from "react-bootstrap";
import UserImage from "../../../shared/components/user_image";
/* global SITE */

const UsersPopover = ( { keyPrefix, users, contents } ) => {
  if ( !users || users.length === 0 ) { return ( <div /> ); }
  const popover = (
    <Popover className="UsersPopoverOverlay" id={ `popover-${keyPrefix}` }>
      { users.map( u => {
        if ( _.isEmpty( u ) ) {
          return (
            <span key={ `popover-${keyPrefix}-${SITE.name}` } className="user">
              <img className="site" src={ SITE.logo_square } title={ SITE.name } />
              { SITE.name }
            </span>
          );
        }
        return (
          <span key={ `popover-${keyPrefix}-${u.id}` } className="user">
            <UserImage user={ u } />
            <a href={ `/people/${u.login}` }>{ u.login }</a>
          </span>
        );
      } ) }
    </Popover>
  );
  return (
    <OverlayTrigger
      trigger="click"
      rootClose
      placement="top"
      animation={false}
      overlay={popover}
    >
      <span className="UsersPopover">
        { contents }
      </span>
    </OverlayTrigger>
  );
};

UsersPopover.propTypes = {
  keyPrefix: PropTypes.string,
  contents: PropTypes.object,
  users: PropTypes.array
};

export default UsersPopover;
