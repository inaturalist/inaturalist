import React, { PropTypes, Component } from "react";
import { DragSource } from "react-dnd";
import { pipe } from "ramda";

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
    let className = "soundDrag";
    if ( this.props.draggingProps &&
         this.props.draggingProps.file &&
         this.props.draggingProps.file.id === this.props.file.id ) {
      className += " drag";
    }
    const source = this.props.file.sound ? (
      <source
        src={ this.props.file.sound.file_url }
        type={ this.props.file.sound.file_content_type }
      />
    ) : (
      <source
        src={ this.props.file.preview }
      />
    );
    return (
      <div>
        { this.props.connectDragSource(
          <div className={ className }>
            <div className="Sound">
              <button
                className="btn btn-link"
                onClick={ () => this.togglePlay( )}
              >
                <i
                  className={`fa fa-5x fa-${this.state.paused ? "play" : "pause"}-circle`}
                  alt={ this.state.paused ? "play" : "pause" }
                />
              </button>
              <audio ref="player" preload="none">
                { source }
                { I18n.t( "your_browser_does_not_support_the_audio_element" ) }
              </audio>
              <small className="text-muted">
                { this.state.duration }<br/>
                { this.props.file.sound ? this.props.file.sound.file_file_name : null }
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
