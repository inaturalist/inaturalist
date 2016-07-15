import React, { PropTypes } from "react";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import SplitTaxon from "./split_taxon";
import UserImage from "./user_image";

const ObservationsGridItem = ( {
  observation: o,
  onObservationClick,
  onAgree,
  toggleReviewed
} ) => {
  let taxonJSX = I18n.t( "unknown" );
  if ( o.taxon && o.taxon !== null ) {
    taxonJSX = (
      <SplitTaxon taxon={o.taxon} url={`/observations/${o.id}`} />
    );
  }
  let wrapperClass = "thumbnail borderless ObservationsGridItem";
  if ( o.reviewedByCurrentUser ) {
    wrapperClass += " reviewed";
  }
  let numReviewers = o.reviewed_by.length;
  if ( o.reviewed_by.indexOf( o.user.id ) >= 0 ) {
    numReviewers = numReviewers - 1;
  }
  const agreeButton = (
    <OverlayTrigger
      placement="bottom"
      overlay={
        <Tooltip id={`agree-tooltip-${o.id}`}>
          { I18n.t( "agree_with_current_taxon" ) }
        </Tooltip>
      }
      container={ $( "#wrapper.bootstrap" ).get( 0 ) }
    >
      <Button
        id={`agree-btn-${o.id}`}
        bsSize="xs"
        bsStyle={o.currentUserAgrees ? "success" : "default"}
        disabled={ !o.taxon || o.currentUserAgrees}
        onClick={ ( ) => {
          onAgree( o );
        } }
      >
        <i className="fa fa-check">
        </i> { _.capitalize( I18n.t( "agree" ) ) }
      </Button>
    </OverlayTrigger>
  );
  const showAgree = o.taxon && o.taxon.rank_level <= 10 && o.taxon.is_active;
  return (
    <div className={wrapperClass}>
      <div className={`reviewed-notice ${o.reviewedByCurrentUser ? "reviewed" : ""}`}>
        <label>
          <input
            type="checkbox"
            checked={ o.reviewedByCurrentUser }
            onChange={ ( ) => {
              toggleReviewed( o );
            } }
          /> { I18n.t( o.reviewedByCurrentUser ? "reviewed" : "mark_as_reviewed" ) }
        </label>
      </div>
      <a
        href={`/observations/${o.id}`}
        style={ {
          backgroundImage: o.photo( ) ? `url( '${o.photo( "medium" )}' )` : ""
        } }
        target="_self"
        className={`photo ${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`}
        onClick={function ( e ) {
          e.preventDefault();
          onObservationClick( o );
          return false;
        } }
      >
        <i className={ `icon icon-iconic-${"unknown"}`} />
        <i className="sound-icon fa fa-volume-up" />
        <div className="magnifier">
          <i className="fa fa-search"></i>
        </div>
      </a>
      <div className="caption">
        <UserImage user={ o.user } />
        { taxonJSX }
        <div className="controls">
          { showAgree ? agreeButton : null }
        </div>
      </div>
    </div>
  );
};

ObservationsGridItem.propTypes = {
  observation: PropTypes.object.isRequired,
  onObservationClick: PropTypes.func,
  onAgree: PropTypes.func,
  toggleReviewed: PropTypes.func
};

export default ObservationsGridItem;
