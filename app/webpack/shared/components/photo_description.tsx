import React from "react";
import {
  Badge,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import ObservationPhotoAttribution from "./observation_photo_attribution";
import HiddenContentMessageContainer from "../containers/hidden_content_message_container";

interface ModeratorAction {
  action: string;
  created_at: string;
  private?: boolean;
  user?: { id: number };
}

export interface DescribedPhoto {
  id: number;
  license_code?: string;
  hidden?: boolean;
  moderator_actions?: ModeratorAction[];
}

interface PhotoDescriptionProps {
  photo: DescribedPhoto;
  observation: { user?: { id: number } };
  currentUser?: { id: number; roles: string[] } | null;
  setFlaggingModalState: ( state: object ) => void;
  hideContent: ( photo: DescribedPhoto ) => void;
  unhideContent: ( photo: DescribedPhoto ) => void;
  revealHiddenContent: ( photo: DescribedPhoto ) => void;
  performOrOpenConfirmationModal: ( method: ( ) => void, options: object ) => void;
}

const FLAG_OPTIONS = ["spam", "copyright infringement", "artificially generated content", "inappropriate"];

const PhotoDescription = ( {
  photo,
  observation,
  currentUser,
  setFlaggingModalState,
  hideContent,
  unhideContent,
  revealHiddenContent,
  performOrOpenConfirmationModal
}: PhotoDescriptionProps ) => {
  const roles = currentUser?.roles || [];
  const isAdmin = roles.includes( "admin" );
  const isCurator = isAdmin || roles.includes( "curator" );
  const isObserver = !!currentUser && currentUser.id === observation.user?.id;
  const latestAction = [...( photo.moderator_actions || [] )]
    .sort( ( a, b ) => b.created_at.localeCompare( a.created_at ) )[0];
  const isPrivate = !!latestAction?.private;
  const hidByCurrentUser = latestAction?.action === "hide"
    && isCurator
    && latestAction.user?.id === currentUser?.id;
  const canToggleHidden = !isObserver && (
    isAdmin
    || ( !photo.hidden && isCurator )
    || ( !!photo.hidden && hidByCurrentUser && !isPrivate )
  );
  const canMakePrivate = !isObserver && isAdmin && !!photo.hidden && !isPrivate;
  const canReveal = isPrivate ? isAdmin : ( isCurator || isObserver );
  const toggleLabel = I18n.t( photo.hidden ? "unhide_content" : "hide_content" );

  const captions = (
    <div className="captions">
      <div className="captions-box">
        <OverlayTrigger
          container={document.querySelector( "#wrapper.bootstrap" )}
          placement="top"
          delayShow={500}
          trigger="click"
          rootClose
          overlay={(
            <Tooltip id={`photo-${photo.id}-license`}>
              <ObservationPhotoAttribution photo={photo} observation={observation} />
            </Tooltip>
          )}
        >
          <i
            className={`fa ${photo.license_code && photo.license_code !== "C"
              ? "fa-creative-commons"
              : "fa-copyright"} license`}
          />
        </OverlayTrigger>
        <button
          type="button"
          className="btn btn-nostyle"
          onClick={( ) => performOrOpenConfirmationModal( ( ) => setFlaggingModalState( {
            item: photo,
            show: true,
            radioOptions: FLAG_OPTIONS
          } ), { permitOwnerOf: observation } )}
          title={I18n.t( "flag_as_inappropriate" )}
          aria-label={I18n.t( "flag_as_inappropriate" )}
        >
          <i className="fa fa-flag" />
        </button>
        { canToggleHidden && (
          <button
            type="button"
            className="btn btn-nostyle"
            onClick={( ) => ( photo.hidden ? unhideContent : hideContent )( photo )}
            title={toggleLabel}
            aria-label={toggleLabel}
          >
            <i className={`fa ${photo.hidden ? "fa-eye" : "fa-eye-slash"}`} />
          </button>
        ) }
        { canMakePrivate && (
          <button
            type="button"
            className="btn btn-nostyle"
            onClick={( ) => hideContent( photo )}
            title={I18n.t( "hide_content" )}
            aria-label={I18n.t( "hide_content" )}
          >
            <i className="fa fa-lock" />
          </button>
        ) }
        <a href={`/photos/${photo.id}`} aria-label={I18n.t( "more_info" )}>
          <Badge>
            <i className="fa fa-info" />
          </Badge>
        </a>
      </div>
    </div>
  );

  if ( !photo.hidden ) {
    return captions;
  }
  return (
    <div className="hidden-media">
      <HiddenContentMessageContainer item={photo} itemType="photos" itemIDField="id" />
      { canReveal && (
        <button
          type="button"
          className="btn btn-default btn-xs reveal-hidden"
          onClick={( ) => revealHiddenContent( photo )}
        >
          { I18n.t( "show_hidden_content" ) }
        </button>
      ) }
      { captions }
    </div>
  );
};

export default PhotoDescription;
