import { connect } from "react-redux";
import { setConfig, updateCurrentUser } from "../../../shared/ducks/config";
import ImageSizeControlButton from "../components/image_size_control_button";

function mapStateToProps( state ) {
  return {
    imageSize: state.config.imageSize
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setImageSize: imageSize => {
      dispatch( setConfig( { imageSize } ) );
      dispatch( updateCurrentUser( { preferred_identify_image_size: imageSize } ) );
    }
  };
}

const ImageSizeControlButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ImageSizeControlButton );

export default ImageSizeControlButtonContainer;
