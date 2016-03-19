var iNatModels = iNatModels || { };

iNatModels.User = function( attrs ) {
  var that = this;
  _.each( attrs, function( value, attr ) {
    that[ attr ] = value;
  });
};

iNatModels.User.default_thumbnail = function( ) {
  return "/attachment_defaults/users/icons/defaults/thumb.png";
};