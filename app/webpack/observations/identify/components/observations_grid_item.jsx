import React, { PropTypes } from "react";
import {
  Button,
  ButtonGroup,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import SplitTaxon from "./split_taxon";

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
  let numAgrees = o.num_identification_agreements;
  // let numAgrees = o.non_owner_ids
  //   .map( ident => ( ident.taxon_id === o.taxon_id ? 1 : 0 ) )
  //   .reduce( ( prev, curr ) => ( prev + curr ), 0 );
  const agreeTooltip = <Tooltip id={`agree-tooltip-${o.id}`}>Agree with current taxon</Tooltip>;
  const reviewTooltip = <Tooltip id={`review-tooltip-${o.id}`}>Toggle reviewed</Tooltip>;
  return (
    <div className={wrapperClass}>
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
      </a>
      <div className="caption">
        <a
          className="userimage"
          href={`/people/${o.user_id}`}
          title={o.user.login}
          style={ {
            backgroundImage: o.user.icon_url ? `url( '${o.user.icon_url}' )` : ""
          } }
          target="_self"
        >
          <i
            className="icon-person"
            style={ {
              display: o.user.icon_url ? "none" : "inline"
            } }
          />
        </a>
        { taxonJSX }
        <ButtonGroup className="controls">
          <OverlayTrigger
            placement="bottom"
            overlay={agreeTooltip}
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
              </i> { numAgrees }
            </Button>
          </OverlayTrigger>
          <OverlayTrigger
            placement="bottom"
            overlay={reviewTooltip}
            container={ $( "#wrapper.bootstrap" ).get( 0 ) }
          >
            <Button
              bsSize="xs"
              bsStyle={o.reviewedByCurrentUser ? "success" : "default"}
              onClick={ ( ) => {
                toggleReviewed( o );
              } }
            >
              <i className={`fa fa-${o.reviewedByCurrentUser ? "eye-slash" : "eye"}`}>
              </i> { numReviewers }
            </Button>
          </OverlayTrigger>
        </ButtonGroup>
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
