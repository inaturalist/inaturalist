import React, { Component } from "react";
import PropTypes from "prop-types";
import { DragSource } from "react-dnd";
import { pipe } from "ramda";
import _ from "lodash";

const soundSource = {
  beginDrag( props ) {
    props.setState( { draggingProps: props } );
    return props;
  },
  endDrag( props ) {
    props.setState( { draggingProps: null } );
    return props;
  }
};

class Sound extends Component {

  static collect( connect, monitor ) {
    return {
      connectDragSource: connect.dragSource( ),
      isDragging: monitor.isDragging( ),
      connectDragPreview: connect.dragPreview( )
    };
  }

  constructor( props ) {
    super( props );
    this.state = {
      paused: true,
      duration: "00:00"
    };
  }

  durationString( durationInSeconds ) {
    var minutes = Math.floor( durationInSeconds / 60 % 60 );
    var hours = minutes / 60 % 60;
    var seconds = Math.round( durationInSeconds ) % 60;
    var duration = `${_.padStart( minutes.toString( ), 2, "0")}:${_.padStart( ""+seconds, 2, "0" )}`;
    if ( hours >= 1 ) {
      duration = `${_.padStart( ""+hours, 2, "0" )}:${duration}`;
    }
    return duration;
  }

  componentDidMount() {
    this.refs.player.addEventListener( "loadeddata", ( ) => {
      this.setState( { duration: this.durationString( this.refs.player.duration ) } );
    } )
    this.refs.player.addEventListener( "timeupdate", ( ) => {
      this.setState( { duration: this.durationString( this.refs.player.currentTime ) } );
    } );
    this.refs.player.addEventListener( "ended", ( ) => {
      this.setState( { paused: true } );
      this.setState( { duration: this.durationString( this.refs.player.duration ) } );
    } );
  }

  togglePlay() {
    if ( this.refs.player.paused ) {
      this.refs.player.play( );
      this.setState( { paused: false } );
    } else {
      this.refs.player.pause( );
      this.setState( { paused: true } );
    }
  }

  render( ) {
    const {
      draggingProps,
      file,
      connectDragSource
    } = this.props;
    const {
      duration,
      paused
    } = this.state;
    let className = "soundDrag";
    if (
      draggingProps
      && draggingProps.file
      && draggingProps.file.id === file.id
    ) {
      className += " drag";
    }
    let source;
    if ( file.sound ) {
      source = (
        <source
          src={file.sound.file_url}
          type={file.sound.file_content_type}
        />
      );
    } else if ( file.file.type !== "audio/amr" ) {
      source = <source src={file.preview} type={file.type} />;
    }
    return (
      <div>
        { connectDragSource(
          <div className={className}>
            <div className="Sound">
              <button
                type="button"
                className="btn btn-link"
                onClick={() => this.togglePlay( )}
                disabled={_.isNil( file.sound )}
              >
                <i
                  className={`fa fa-5x fa-${paused ? "play" : "pause"}-circle`}
                  alt={paused ? "play" : "pause"}
                />
              </button>
              <audio ref="player" preload="none">
                { source }
                { I18n.t( "your_browser_does_not_support_the_audio_element" ) }
              </audio>
              <small className="text-muted">
                { duration }
                <br />
                { file.name }
              </small>
            </div>
          </div>
        ) }
      </div>
    );
  }
}

Sound.propTypes = {
  src: PropTypes.string,
  obsCard: PropTypes.object,
  file: PropTypes.object,
  onClick: PropTypes.func,
  setState: PropTypes.func,
  confirmRemoveFile: PropTypes.func,
  draggingProps: PropTypes.object,
  connectDragSource: PropTypes.func,
  connectDragPreview: PropTypes.func
};

export default pipe(
  DragSource( "Sound", soundSource, Sound.collect )
)( Sound );
