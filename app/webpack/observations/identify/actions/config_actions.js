const CONFIG = "CONFIG";
function setConfig( config ) {
  return {
    type: CONFIG,
    config
  };
}

export { CONFIG, setConfig };

