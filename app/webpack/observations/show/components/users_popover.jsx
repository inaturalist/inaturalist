import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { Popover, OverlayTrigger } from "react-bootstrap";
import UserImage from "../../../shared/components/user_image";
/* global SITE */

const UsersPopover = ( {
  keyPrefix,
  users,
  contents,
  placement,
  returnContentsWhenEmpty,
  contentAfterUsers,
  containerPadding
} ) => {
  if ( !users || users.length === 0 ) {
    return returnContentsWhenEmpty ? contents : ( <span /> );
  }
  const popover = (
    <Popover className="UsersPopoverOverlay" id={`popover-${keyPrefix}`}>
      { users.map( u => {
        if ( _.isEmpty( u ) ) {
          return (
            <span key={`popover-${keyPrefix}-${SITE.name}`} className="user">
              <img className="site" src={SITE.logo_square} title={SITE.name} alt={SITE.name} />
              { SITE.name }
            </span>
          );
        }
        return (
          <span key={`popover-${keyPrefix}-${u.id}`} className="user">
            <UserImage user={u} />
            <a href={`/people/${u.login}`}>{ u.login }</a>
          </span>
        );
      } ) }
      { contentAfterUsers }
    </Popover>
  );
  return (
    <OverlayTrigger
      trigger="click"
      rootClose
      placement={placement || "top"}
      animation={false}
      overlay={popover}
      containerPadding={containerPadding}
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
  users: PropTypes.array,
  placement: PropTypes.string,
  containerPadding: PropTypes.number,
  contentAfterUsers: PropTypes.object,
  returnContentsWhenEmpty: PropTypes.bool
};

export default UsersPopover;
