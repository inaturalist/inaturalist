import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ConfirmEmailModalContainer from "../../../shared/containers/confirm_email_modal_container";

const Banner = ( {
  config,
  confirmResendConfirmation,
  confirmationEmailSent
} ) => {
  if ( confirmationEmailSent ) {
    return (
      <div>
        <div>
          <span
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.email_confirmation.please_click_the_link_sent_to_email_to_confirm_html", {
                email: config.currentUser.email
              } )
            }}
          />
          <ConfirmEmailModalContainer />
        </div>
      </div>
    );
  }

  return (
    <div>
      <div
        role="button"
        tabIndex={0}
        onClick={( ) => confirmResendConfirmation( )}
        onKeyDown={e => {
          const key = e.keyCode || e.which;
          if ( key === 13 ) {
            confirmResendConfirmation( );
          }
        }}
        label={I18n.t( "views.email_confirmation.click_here_to_resend_a_confirmation_email" )}
      >
        <span
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.email_confirmation.please_confirm_your_email_address_html", {
              email: config.currentUser.email
            } )
          }}
        />
        {" "}
        <button
          type="button"
          id="emailConfirmationModalButton"
          className={_.includes( config.currentUser?.privileges, "interaction" ) ? null : "lacking-interaction"}
          onClick={( ) => confirmResendConfirmation( )}
        >
          {I18n.t( "views.email_confirmation.click_here_to_resend_a_confirmation_email" )}
        </button>
        .
      </div>
      <ConfirmEmailModalContainer />
    </div>
  );
};

Banner.propTypes = {
  config: PropTypes.object,
  confirmResendConfirmation: PropTypes.func,
  confirmationEmailSent: PropTypes.bool
};

export default Banner;
