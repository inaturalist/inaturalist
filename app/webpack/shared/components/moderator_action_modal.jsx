import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";
import {
  Comment,
  Identification,
  Photo,
  Sound
} from "inaturalistjs";
import UserText from "./user_text";
import HiddenContentMessageContainer from "../containers/hidden_content_message_container";

const ModeratorActionModal = ( {
  visible,
  hide,
  item,
  action,
  submit,
  revealHiddenContent
} ) => {
  if ( !item ) {
    return null;
  }
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
  let contentPreview;
  if ( item instanceof Comment || item instanceof Identification ) {
    contentPreview = (
      <div>
        <p
          dangerouslySetInnerHTML={{
            __html: I18n.t( "user_wrote_html", { user: login, url: `/people/${login}` } )
          }}
        />
        <blockquote>
          <UserText text={contentToHide} truncate={200} />
        </blockquote>
      </div>
    );
  } else if ( item.hidden && ( item instanceof Photo || item instanceof Sound ) ) {
    contentPreview = (
      <div className="hidden-media">
        <HiddenContentMessageContainer
          item={item}
          itemType="photos"
          itemIDField="id"
        />
        <button
          type="button"
          className="btn btn-default btn-xs reveal-hidden"
          onClick={( ) => revealHiddenContent( item )}
        >
          { I18n.t( "show_hidden_content" ) }
        </button>
      </div>
    );
  } else if ( item instanceof Photo ) {
    contentPreview = (
      <div className="image-preview">
        <img src={item.photoUrl( "medium" )} alt="" />
      </div>
    );
  } else if ( item instanceof Sound ) {
    let player;
    let containerClass = "sound-container-local";
    if ( !item.play_local && ( item.subtype === "SoundcloudSound" || !item.file_url ) ) {
      containerClass = "sound-container-soundcloud";
      player = (
        <iframe
          title="Soundcloud"
          scrolling="no"
          frameBorder="no"
          src={
            `https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F${item.native_sound_id}&show_artwork=false&secret_token=${item.secret_token}`
          }
        />
      );
    } else {
      player = (
        <audio controls preload="none" controlsList="nodownload">
          <source src={item.file_url} type={item.file_content_type} />
          { I18n.t( "your_browser_does_not_support_the_audio_element" ) }
        </audio>
      );
    }
    contentPreview = (
      <div className={`sound-container ${containerClass}`}>
        <div className="sound">
          { player }
        </div>
      </div>
    );
  } else {
    throw new Error( "Can't moderate content of an unknown type" );
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
          {contentPreview}
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
  submit: PropTypes.func,
  revealHiddenContent: PropTypes.func
};

ModeratorActionModal.defaultProps = {
  action: "hide",
  visible: false
};

export default ModeratorActionModal;
