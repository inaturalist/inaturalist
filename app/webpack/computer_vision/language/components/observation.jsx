import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import moment from "moment-timezone";
// eslint-disable-next-line no-unused-vars
import EasyZoom from "EasyZoom/dist/easyzoom";
import Lightbox from "../../../shared/components/inat_lightbox";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../../shared/components/user_image";

const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
if ( shortRelativeTime ) {
  moment.updateLocale( I18n.locale, { relativeTime: shortRelativeTime } );
}

class Observation extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.state = {
      lightboxOpen: false
    };
  }

  componentDidMount( ) {
    setTimeout( ( ) => { this.easyzoom( ); }, 200 );
  }

  componentDidUpdate( ) {
    setTimeout( ( ) => { this.easyzoom( ); }, 200 );
  }

  easyzoom( ) {
    $( "#lightboxBackdrop figure > img" ).wrap( function ( ) {
      let imgUrl = $( this ).attr( "src" );
      if ( $( this ).attr( "srcset" ) ) {
        const matches = $( this ).attr( "srcset" ).match( /^(.*?) / );
        imgUrl = matches[1];
      }
      return `<div class="easyzoom"><a href="${imgUrl}"></a></div>`;
    } );
    const easyZoomTarget = $( "#lightboxBackdrop .easyzoom" );
    easyZoomTarget.easyZoom( {
      eventType: "click",
      onShow( ) {
        this.$link.addClass( "easyzoom-zoomed" );
      },
      onHide( ) {
        this.$link.removeClass( "easyzoom-zoomed" );
      },
      loadingNotice: I18n.t( "loading" )
    } );
    $( "#lightboxBackdrop .easyzoom a" ).unbind( "click" );
    $( "#lightboxBackdrop .easyzoom a" ).on( "click", e => {
      if ( !$( e.target ).is( "img" ) ) {
        this.setState( { lightboxOpen: false } );
      }
    } );
  }

  render( ) {
    const {
      observation,
      config,
      photoID,
      voteOnPhoto,
      votes,
      votingEnabled
    } = this.props;
    const thumbs = votingEnabled ? (
      <div className="thumbs">
        <button
          type="button"
          className={`thumbs-up${votes[photoID] === true ? " active" : ""}`}
          onClick={() => {
            voteOnPhoto( photoID, true );
          }}
          title={I18n.t( "views.nls_demo.mark_as_relevant" )}
          label={I18n.t( "views.nls_demo.mark_as_relevant" )}
        >
          <i className="fa fa-thumbs-up" />
        </button>
        <button
          type="button"
          className={`thumbs-down${votes[photoID] === false ? " active" : ""}`}
          onClick={() => {
            voteOnPhoto( photoID, false );
          }}
          title={I18n.t( "views.nls_demo.mark_as_not_relevant" )}
          label={I18n.t( "views.nls_demo.mark_as_not_relevant" )}
        >
          <i className="fa fa-thumbs-down" />
        </button>
      </div>
    ) : ( <div className="thumbs" /> );
    const classes = ["caption", "flex-grow-1"];
    if ( votes[photoID] === true ) {
      classes.push( "voted-up" );
    } else if ( votes[photoID] === false ) {
      classes.push( "voted-down" );
    }
    const caption = (
      <div className={classes.join( " " )}>
        <div className="names">
          <SplitTaxon
            taxon={observation.taxon}
            noParens
            user={config.currentUser}
            url={`/observations/${observation.id}?photo_id=${photoID}`}
            target="_blank"
            noInactive
          />
          <UserImage user={observation.user} />
        </div>
        { thumbs }
      </div>
    );
    let img;
    let lightbox;
    if ( observation.photos.length > 0 ) {
      const photo = _.find( observation.photos, p => p.id === photoID );
      img = (
        <div
          role="button"
          className="lightbox-opener"
          onClick={() => this.setState( { lightboxOpen: true } )}
          aria-hidden="true"
        >
          <CoverImage
            src={photo.photoUrl( "medium" )}
            low={photo.photoUrl( "small" )}
          />
        </div>
      );
      lightbox = (
        <Lightbox
          key={`lightbox-${photoID}`}
          isOpen={this.state.lightboxOpen}
          showImageCount={false}
          images={[{
            src: photo.photoUrl( "large" ),
            srcset: [
              `${photo.photoUrl( "original" )} 2048w`,
              `${photo.photoUrl( "large" )} 1024w`,
              `${photo.photoUrl( "medium" )} 200w`
            ]
          }]}
          onClose={() => this.setState( { lightboxOpen: false } )}
          backdropClosesModal
          width={5000}
        />
      );
    }
    return (
      <div
        className="ObservationsGridCell d-flex flex-grow-1"
        key={`observation-grid-cell-${observation.id}`}
      >
        <div
          className="Observation d-flex flex-grow-1 flex-column"
        >
          { img }
          { lightbox }
          { caption }
        </div>
      </div>
    );
  }
}

Observation.propTypes = {
  observation: PropTypes.object.isRequired,
  photoID: PropTypes.number,
  voteOnPhoto: PropTypes.func,
  votes: PropTypes.object,
  votingEnabled: PropTypes.bool,
  config: PropTypes.object
};

Observation.defaultProps = {
  config: {}
};

export default Observation;
