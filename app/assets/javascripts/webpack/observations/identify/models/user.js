class User {
  constructor( attrs ) {
    for ( const attr of Object.keys( attrs ) ) {
      this[attr] = attrs[attr];
    }
  }
}

export default User;
