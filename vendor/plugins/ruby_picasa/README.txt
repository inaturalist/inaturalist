= ruby_picasa

* http://github.com/pangloss/ruby_picasa

== DESCRIPTION:

Provides a super easy to use object layer for authenticating and accessing
Picasa through their API.

== FEATURES:

* Simplifies the process of obtaining both a temporary and a permanent AuthSub
  token.
* Very easy to use API.
* Allows access to both public and private User, Album and Photo data.
* Uses Objectify::Xml to define the XML object-relational layer with a very
  easy to understand DSL. See www.github.com/pangloss/objectify_xml

== PROBLEMS:

* None known.

== SYNOPSIS:

  # 1. Authorize application for access (in a rails controller)
  #
  redirect_to RubyPicasa.authorization_url(auth_result_url)

  # 2. Extract the Picasa token from the request Picasa sends back to your app
  #    and create a permanent AuthSub token. Returns an initialized Picasa
  #    session.  (Called from the Rails action for auth_result_url above)
  picasa = RubyPicasa.authorize_request(self.request)

  # 3. Access the data you are interested in
  @album = picasa.user.albums.first
  @photo = @album.photos.first

  # 4. Display your photos
  image_tag @photo.url
  image_tag @photo.url('160c') # Picasa thumbnail names are predefined

== REQUIREMENTS:

* objectify_xml

== INSTALL:

* script/plugin install git://github.com/amuino/ruby_picasa.git
== LICENSE:

(The MIT License)

Copyright (c) 2009 Darrick Wiebe

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
