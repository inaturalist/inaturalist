import { render } from "react-dom";
import React from "react";
import TorqueMap from "../../shared/components/torque_map";
/* global MAP_PARAMS */

render(
  <TorqueMap
    params={ MAP_PARAMS }
    interval={ MAP_PARAMS.interval === "weekly" ? "weekly" : "monthly" }
  />,
  document.getElementById( "app" )
);
