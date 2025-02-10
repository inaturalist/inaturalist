import React from "react";
import PropTypes from "prop-types";
import { Panel } from "react-bootstrap";

import HiddenContentMessageContainer from "../../../shared/containers/hidden_content_message_container";
import UserImage from "../../../shared/components/user_image";

const HiddenActivityItem = ( {
  canSeeHidden,
  hideUserIcon,
  isID,
  item,
  showHidden,
  viewerIsActor
} ) => (
  <div className="ActivityItem">
    { hideUserIcon ? null : (
      <div className="icon">
        <UserImage user={viewerIsActor ? item.user : null} />
      </div>
    ) }
    <Panel className="moderator-hidden">
      <Panel.Heading>
        <Panel.Title>
          <span className="title_text text-muted">
            <i>
              <HiddenContentMessageContainer
                key={`hidden-tooltip-${item.uuid}`}
                item={item}
                itemType={isID ? "identifications" : "comments"}
              />
            </i>
          </span>
          {canSeeHidden && (
            <button
              href="#"
              type="button"
              className="btn btn-default btn-xs"
              onClick={() => showHidden()}
            >
              {I18n.t( "show_hidden_content" )}
            </button>
          )}
        </Panel.Title>
      </Panel.Heading>
    </Panel>
  </div>
);

HiddenActivityItem.propTypes = {
  canSeeHidden: PropTypes.bool,
  hideUserIcon: PropTypes.bool,
  isID: PropTypes.bool,
  item: PropTypes.object,
  showHidden: PropTypes.func,
  viewerIsActor: PropTypes.bool
};

export default HiddenActivityItem;
