import React from "react";
import PropTypes from "prop-types";
import WaveSurfer from "wavesurfer.js";
// eslint-disable-next-line import/extensions
import Spectrogram from "wavesurfer.js/dist/plugins/spectrogram.esm.js";
// eslint-disable-next-line import/extensions
import TimelinePlugin from "wavesurfer.js/dist/plugins/timeline.esm.js";
// eslint-disable-next-line import/extensions
// import Minimap from "wavesurfer.js/dist/plugins/minimap.esm.js";

import { COLORS } from "../../../shared/util";

const HEIGHT = 350;

const SoundPlayer = ( { soundUrl } ) => {
  const ref = React.useRef( null );

  React.useEffect( ( ) => {
    if ( !ref.current ) return;

    const ws = WaveSurfer.create( {
      container: ref.current,
      cursorWidth: 2,
      cursorColor: COLORS.inatGreen,
      dragToSeek: true,
      url: soundUrl,
      mediaControls: true,
      // Don't render the default waveform
      height: 0
      // This would allow a standard rendering of time, but currently it
      // causes a very annoying flicker, so we'd need to fix that bug before
      // using it
      // minPxPerSec: 100,
      // hideScrollbar: true,
      // autoCenter: false,
    } );
    ws.registerPlugin(
      Spectrogram.create( {
        colorMap: "gray",
        labels: true,
        height: HEIGHT,
        scale: "linear",
        labelsBackground: "rgba(0, 0, 0, 0.3)"
      } )
    );
    ws.registerPlugin(
      TimelinePlugin.create( {
        style: "color: #333",
        secondaryLabelOpacity: 1
      } )
    );
    // If we can set a standard rendering of time, this would become useful
    // ws.registerPlugin(
    //   Minimap.create( {
    //     height: 20,
    //     waveColor: "#ddd",
    //     progressColor: "#999"
    //   } )
    // );
  }, [] );

  return (
    <div
      className="SoundPlayer"
      ref={ref}
      style={{ width: "100%", height: HEIGHT }}
    />
  );
};

SoundPlayer.propTypes = {
  soundUrl: PropTypes.string
};

export default SoundPlayer;
