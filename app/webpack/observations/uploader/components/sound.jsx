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

  static durationString( durationInSeconds ) {
    const minutes = Math.floor( ( durationInSeconds / 60 ) % 60 );
    const hours = ( minutes / 60 ) % 60;
    const seconds = Math.round( durationInSeconds ) % 60;
    let duration = `${_.padStart( minutes.toString( ), 2, "0" )}:${_.padStart( `${seconds}`, 2, "0" )}`;
    if ( hours >= 1 ) {
      duration = `${_.padStart( `${hours}`, 2, "0" )}:${duration}`;
    }
    return duration;
  }

  constructor( props ) {
    super( props );
    this.state = {
      paused: true,
      duration: "00:00"
    };
    this.player = React.createRef( );
  }

  componentDidMount() {
    const player = this.player.current;
    if ( !player ) return;
    player.addEventListener( "loadeddata", ( ) => {
      this.setState( { duration: Sound.durationString( player.duration ) } );
    } );
    player.addEventListener( "timeupdate", ( ) => {
      this.setState( { duration: Sound.durationString( player.currentTime ) } );
    } );
    player.addEventListener( "ended", ( ) => {
      this.setState( { paused: true } );
      this.setState( { duration: Sound.durationString( player.duration ) } );
    } );
  }

  togglePlay() {
    const player = this.player.current;
    if ( !player ) return;
    if ( player.paused ) {
      player.play( );
      this.setState( { paused: false } );
    } else {
      player.pause( );
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
    // The <source> element doesn't seem to change with new props, so we should
    // only try and use file.preview for playback for formats that we're pretty
    // sure will play in all browsers
    if ( file.sound ) {
      source = (
        <source
          src={file.sound.file_url}
          type={file.sound.file_content_type}
        />
      );
    } else if ( file.type.match( /wav|mp3/ ) ) {
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
              <audio ref={this.player} preload="none">
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
  file: PropTypes.object,
  draggingProps: PropTypes.object,
  connectDragSource: PropTypes.func
};

export default pipe(
  DragSource( "Sound", soundSource, Sound.collect )
)( Sound );
