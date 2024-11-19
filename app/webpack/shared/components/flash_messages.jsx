import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import sha256 from "crypto-js/sha256";
import FlashMessage from "../../observations/show/components/flash_message";

/* global RAILS_FLASH */

const FlashMessages = ( {
  config, item, manageFlagsPath, showBlocks
} ) => {
  const flashes = [];
  if ( !_.isEmpty( RAILS_FLASH ) ) {
    const types = [
      { flashType: "notice", bootstrapType: "success" },
      { flashType: "alert", bootstrapType: "success" },
      { flashType: "warning", bootstrapType: "warning" },
      { flashType: "error", bootstrapType: "error" }
    ];
    _.each( types, type => {
      if ( RAILS_FLASH[type.flashType]
           && RAILS_FLASH[`${[type.flashType]}_title`] !== I18n.t(
             "views.shared.spam.this_has_been_flagged_as_spam"
           ) ) {
        flashes.push( <FlashMessage
          key={`flash_${type.flashType}`}
          title={RAILS_FLASH[`${[type.flashType]}_title`]}
          message={RAILS_FLASH[type.flashType]}
          type={type.bootstrapType}
        /> );
      }
    } );
  }
  if ( !_.isEmpty( item ) ) {
    if ( !_.isEmpty( item.flags ) ) {
      const unresolvedFlags = _.filter( item.flags, f => !f.resolved );
      if ( _.find( unresolvedFlags, f => f.flag === "spam" ) ) {
        const message = (
          <span
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: I18n.t(
                "item_flagged_notice_html",
                {
                  help_email: SITE.help_email,
                  manage_flags_path: manageFlagsPath
                }
              )
            }}
          />
        );
        flashes.push( <FlashMessage
          key="flash_flag"
          title={I18n.t( "views.shared.spam.this_has_been_flagged_as_spam" )}
          message={message}
          type="flag"
        /> );
      }
    }
    if (
      showBlocks
      && item.user
      && config.currentUser
      && _.find(
        config.currentUser.blockedByUserHashes,
        h => sha256( item.user.id.toString( ) ).toString( ) === h
      )
    ) {
      flashes.push( <FlashMessage
        key="flash_blocked"
        title={I18n.t( "views.shared.blocked.youve_been_blocked" )}
        message={I18n.t( "views.shared.blocked.youve_been_blocked_desc" )}
        type="warning"
      /> );
    } else if (
      config.currentUser
      && _.find(
        config.currentUser.blockedUserHashes,
        h => sha256( item.user.id.toString( ) ).toString( ) === h
      )
    ) {
      flashes.push( <FlashMessage
        key="flash_blocked"
        title={I18n.t( "views.shared.blocked.youve_blocked" )}
        message={I18n.t( "views.shared.blocked.youve_blocked_desc" )}
        type="warning"
      /> );
    }
  }
  return _.isEmpty( flashes ) ? <span /> : (
    <div className="FlashMessages">
      { flashes }
    </div>
  );
};

FlashMessages.propTypes = {
  config: PropTypes.object,
  showBlocks: PropTypes.bool,
  manageFlagsPath: PropTypes.string,
  item: PropTypes.object
};

export default FlashMessages;
