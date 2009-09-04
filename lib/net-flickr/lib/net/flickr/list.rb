#--
# Copyright (c) 2007-2008 Ryan Grove <ryan@wonko.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#   * Neither the name of this project nor the names of its contributors may be
#     used to endorse or promote products derived from this software without
#     specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++

module Net; class Flickr

  # Base class for paginated lists.
  # 
  # Don't instantiate this class yourself. It's a base class extended by
  # +PhotoList+ and others.
  class List
    include Enumerable
    
    attr_reader :page, :pages, :per_page, :total
    
    def initialize(load_method, load_args)
      @load_method = load_method
      @load_args   = load_args
      
      update_list
    end
    
    #--
    # Public Instance Methods
    #++
    
    def size
      @items.size
    end
    
    def [](index)
      return @items[index]
    end
    
    def each
      @items.each {|item| yield item }
    end
    
    # Returns +true+ if the current page is the first page of the list, +false+
    # otherwise.
    def first_page?
      return @page == 1
    end
    
    # Returns +true+ if the current page is the last page of the list, +false+
    # otherwise.
    def last_page?
      return @page == @pages
    end
    
    # Loads the next page in the list.
    def next
      if last_page?
        raise ListError, 'Already on the last page of the list'
      end
      
      @load_args['page'] = @page + 1      
      update_list
    end
    
    # Loads the specified page in the list.
    def page=(page)
      if page < 1 || page > @pages
        raise ArgumentError, 'Page number out of bounds'
      end
      
      @load_args['page'] = page
      update_list
    end
    
    # Sets the number of items loaded per page. Must be between 1 and 500
    # inclusive.
    def per_page=(per_page)
      if per_page < 1 || per_page > 500
        raise ArgumentError, 'per_page must be between 1 and 500 inclusive'
      end
      
      @per_page = per_page
      @load_args['per_page'] = @per_page
    end
    
    # Loads the previous page in the list.
    def previous
      if first_page?
        raise ListError, 'Already on the first page of the list'
      end
      
      @load_args['page'] = @page - 1
      update_list
    end
    
    alias prev previous
    
    #--
    # Private Instance Methods
    #++
    
    private
    
    def update_list
      @items = []
      
      @response = Net::Flickr.instance().request(@load_method, @load_args).
          at('/*[@page]:first')
      
      @per_page = @response['perpage'].to_i
      @page     = @response['page'].to_i
      @pages    = @response['pages'].to_i
      @total    = @response['total'].to_i
    end
    
  end

end; end
