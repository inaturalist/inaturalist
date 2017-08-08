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

  render( ) {
    let className = "soundDrag";
    if ( this.props.draggingProps &&
         this.props.draggingProps.file &&
         this.props.draggingProps.file.id === this.props.file.id ) {
      className += " drag";
    }
    return (
      <div>
        { this.props.connectDragSource(
          <div className={ className }>
            <div className="Sound">
              <audio controls preload="none">
                <source
                  src={ this.props.file.sound.file_url }
                  type={ this.props.file.sound.file_content_type }
                />
                Your browser does not support the audio element.
              </audio>
              <small className="text-muted">
                { this.props.file.sound.file_file_name }
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
