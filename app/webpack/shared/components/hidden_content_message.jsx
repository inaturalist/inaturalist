import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOMServer from "react-dom/server";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import UserText from "./user_text";

const HiddenContentMessage = ( {
  item,
  itemType,
  itemIDField,
  shrinkOnNarrowDisplays,
  config
} ) => {
  if ( !item.hidden ) {
    return null;
  }
  const viewerIsActor = config.currentUser && item.user.id === config.currentUser.id;
  const moderatorAction = _.sortBy(
    _.filter( item.moderator_actions, ma => ma.action === "hide" ),
    ma => ma.id * -1
  )[0];
  const maUserLink = (
    <a
      href={`/people/${moderatorAction.user.login}`}
      target="_blank"
      rel="noopener noreferrer"
    >
      {`@${moderatorAction.user.login}`}
    </a>
  );
  return (
    <OverlayTrigger
      key={`hidden-tooltip-${itemType}-${item[itemIDField]}`}
      container={$( "#wrapper.bootstrap" ).get( 0 )}
      placement="top"
      trigger="click"
      rootClose
      delayShow={200}
      overlay={(
        <Popover
          id={`hidden-${itemType}-${item[itemIDField]}`}
          className="unhide-popover"
        >
          <span
            dangerouslySetInnerHTML={{
              __html: I18n.t( "content_hidden_by_user_on_date_because_reason_html", {
                user: ReactDOMServer.renderToString( maUserLink ),
                date: I18n.localize( "date.formats.month_day_year", moderatorAction.created_at ),
                reason: ReactDOMServer.renderToString( <UserText text={moderatorAction.reason} className="inline" /> )
              } )
            }}
          />
          <div className="upstacked text-muted">
            <a
              href={`/${itemType}/${item[itemIDField]}/flags`}
              target="_blank"
              rel="noopener noreferrer"
              className="linky"
            >
              {I18n.t( "view_flags" )}
            </a>
            {viewerIsActor && (
              <span>
                <br />
                <a
                  href="/help"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="linky"
                >
                  {I18n.t( "contact_support" )}
                </a>
              </span>
            )}
          </div>
        </Popover>
      )}
    >
      <span className="item-status hidden-status">
        <i className="fa fa-eye-slash" title={I18n.t( "content_hidden" )} />
        <span className={shrinkOnNarrowDisplays ? "hidden-xs hidden-sm" : ""}>
          {" "}
          {I18n.t( "content_hidden" )}
        </span>
      </span>
    </OverlayTrigger>
  );
};

HiddenContentMessage.propTypes = {
  item: PropTypes.object,
  itemType: PropTypes.string,
  itemIDField: PropTypes.string,
  shrinkOnNarrowDisplays: PropTypes.bool,
  config: PropTypes.object
};

HiddenContentMessage.defaultProps = {
  shrinkOnNarrowDisplays: false,
  itemIDField: "uuid"
};

export default HiddenContentMessage;
