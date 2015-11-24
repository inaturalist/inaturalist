var iNatModels = iNatModels || { };

iNatModels.User = function( attrs ) {
  var that = this;
  _.each( attrs, function( value, attr ) {
    that[ attr ] = value;
  });
};
