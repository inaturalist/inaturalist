var iNatModels = iNatModels || { };

iNatModels.Place = function( attrs ) {
  var that = this;
  _.each( attrs, function( value, attr ) {
    that[ attr ] = value;
  });
};
