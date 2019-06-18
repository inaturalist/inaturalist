import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";
import UserText from "./user_text";

const ModeratorActionModal = ( {
  visible,
  hide,
  item,
  action,
  submit
} ) => {
  let verb = I18n.t( "hide_content" );
  const contentToHide = item ? item.body : "";
  let placeholder = I18n.t( "please_explain_why_you_want_to_hide_this" );
  let explanation = I18n.t( "hide_desc" );
  const login = item ? item.user.login : "";
  if ( action === "unhide" ) {
    verb = I18n.t( "unhide_content" );
    placeholder = I18n.t( "please_explain_why_you_want_to_unhide_this" );
    explanation = I18n.t( "unhide_desc" );
  }
  return (
    <Modal
      show={visible}
      className="ModeratorActionModal"
      onHide={( ) => hide( )}
    >
      <form
        onSubmit={e => {
          e.preventDefault( );
          const formData = new FormData( e.target );
          const reason = formData.get( "reason" );
          submit( item, action, reason );
          return false;
        }}
      >
        <Modal.Header closeButton>
          <Modal.Title>
            { verb }
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <p
            dangerouslySetInnerHTML={{
              __html: I18n.t( "user_wrote_html", { user: login, url: `/people/${login}` } )
            }}
          />
          <blockquote>
            <UserText text={contentToHide} truncate={200} />
          </blockquote>
          <textarea name="reason" className="form-control" placeholder={placeholder} required />
          <input type="hidden" name="action" value={action || ""} />
          <div className="text upstacked text-muted">{ explanation }</div>
        </Modal.Body>
        <Modal.Footer>
          <div className="buttons">
            <button type="button" className="btn btn-default" onClick={( ) => hide()}>
              { I18n.t( "cancel" ) }
            </button>
            <input type="submit" className="btn btn-primary" value={verb} />
          </div>
        </Modal.Footer>
      </form>
    </Modal>
  );
};

ModeratorActionModal.propTypes = {
  visible: PropTypes.bool,
  hide: PropTypes.func,
  action: PropTypes.string,
  item: PropTypes.object,
  submit: PropTypes.func
};

ModeratorActionModal.defaultProps = {
  action: "hide",
  visible: false
};

export default ModeratorActionModal;
