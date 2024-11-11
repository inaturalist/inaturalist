// Extension of react-images lightbox to provide RTL keyboard shortcuts

import Lightbox from "react-images";

class INatLightbox extends Lightbox {
  handleKeyboardInput( event ) {
    const isRTL = $( "html[dir='rtl']" ).length > 0;
    if ( event.keyCode === 37 ) { // left
      if ( isRTL ) {
        this.gotoNext( event );
      } else {
        this.gotoPrev( event );
      }
      return true;
    } if ( event.keyCode === 39 ) { // right
      if ( isRTL ) {
        this.gotoPrev( event );
      } else {
        this.gotoNext( event );
      }
      return true;
    } if ( event.keyCode === 27 ) { // esc
      this.props.onClose();
      return true;
    }
    return false;
  }
}

export default INatLightbox;
