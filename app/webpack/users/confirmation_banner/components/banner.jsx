import React from "react";
import PropTypes from "prop-types";

import ConfirmModalContainer from "../../edit/containers/confirm_modal_container";

const Banner = ( {
  config,
  confirmResendConfirmation,
  confirmationEmailSent
} ) => {
  if ( confirmationEmailSent ) {
    return (
      <div>
        <span
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.email_confirmation.please_click_the_link_sent_to_email_to_confirm_html", {
              email: config.currentUser.email
            } )
          }}
        />
        <ConfirmModalContainer />
      </div>
    );
  }

  return (
    <div>
      <span
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{
          __html: I18n.t( "views.email_confirmation.please_confirm_that_email_is_the_best_contact2_html", {
            email: config.currentUser.email
          } )
        }}
      />
      {" "}
      <button
        type="button"
        id="emailConfirmationModalButton"
        onClick={( ) => confirmResendConfirmation( )}
      >
        {I18n.t( "views.email_confirmation.click_here_to_resend_a_confirmation_email" )}
      </button>
      .
      <ConfirmModalContainer />
    </div>
  );
};

Banner.propTypes = {
  config: PropTypes.object,
  confirmResendConfirmation: PropTypes.func,
  confirmationEmailSent: PropTypes.bool
};

export default Banner;
