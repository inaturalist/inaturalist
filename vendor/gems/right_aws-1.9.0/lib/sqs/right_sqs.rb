#
# Copyright (c) 2007-2008 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

module RightAws

    #
    # = RightAws::Sqs -- RightScale's Amazon SQS interface
    # The RightAws::Sqs class provides a complete interface to Amazon's Simple
    # Queue Service.
    # For explanations of the semantics
    # of each call, please refer to Amazon's documentation at
    # http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=31
    #
    # Error handling: all operations raise an RightAws::AwsError in case
    # of problems. Note that transient errors are automatically retried.
    #
    #  sqs    = RightAws::Sqs.new(aws_access_key_id, aws_secret_access_key)
    #  queue1 = sqs.queue('my_awesome_queue')
    #   ...
    #  queue2 = RightAws::Sqs::Queue.create(sqs, 'my_cool_queue', true)
    #  puts queue2.size
    #   ...
    #  message1 = queue2.receive
    #  message1.visibility = 0
    #  puts message1
    #   ...
    #  queue2.clear(true)
    #  queue2.send_message('Ola-la!')
    #  message2 = queue2.pop
    #   ...
    #  grantee1 = RightAws::Sqs::Grantee.create(queue2,'one_cool_guy@email.address')
    #  grantee1.grant('FULLCONTROL')
    #  grantee1.drop
    #   ...
    #  grantee2 = queue.grantees('another_cool_guy@email.address')
    #  grantee2.revoke('SENDMESSAGE')
    #       
    # Params is a hash:
    #
    #    {:server       => 'queue.amazonaws.com' # Amazon service host: 'queue.amazonaws.com' (default)
    #     :port         => 443                   # Amazon service port: 80 or 443 (default)
    #     :multi_thread => true|false            # Multi-threaded (connection per each thread): true or false (default)
    #     :signature_version => '0'              # The signature version : '0' or '1'(default)
    #     :logger       => Logger Object}        # Logger instance: logs to STDOUT if omitted }
    #
  class Sqs
    attr_reader :interface
    
    def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
      @interface = SqsInterface.new(aws_access_key_id, aws_secret_access_key, params)
    end
    
      # Retrieves a list of queues. 
      # Returns an +array+ of +Queue+ instances.
      #
      #  RightAws::Sqs.queues #=> array of queues
      #
    def queues(prefix=nil)
      @interface.list_queues(prefix).map do |url|
        Queue.new(self, url)
      end
    end
    
      # Returns Queue instance by queue name. 
      # If the queue does not exist at Amazon SQS and +create+ is true, the method creates it.
      #
      #  RightAws::Sqs.queue('my_awesome_queue') #=> #<RightAws::Sqs::Queue:0xb7b626e4 ... >
      #
    def queue(queue_name, create=true, visibility=nil)
      url = @interface.queue_url_by_name(queue_name)
      url = (create ? @interface.create_queue(queue_name, visibility) : nil) unless url
      url ? Queue.new(self, url) : nil
    end
  
  
    class Queue
      attr_reader :name, :url, :sqs
      
        # Returns Queue instance by queue name. 
        # If the queue does not exist at Amazon SQS and +create+ is true, the method creates it.
        #
        #  RightAws::Sqs::Queue.create(sqs, 'my_awesome_queue') #=> #<RightAws::Sqs::Queue:0xb7b626e4 ... >
        #
      def self.create(sqs, url_or_name, create=true, visibility=nil)
        sqs.queue(url_or_name, create, visibility)
      end
      
        # Creates new Queue instance. 
        # Does not create a queue at Amazon.
        #
        #  queue = RightAws::Sqs::Queue.new(sqs, 'my_awesome_queue')
        #
      def initialize(sqs, url_or_name)
        @sqs  = sqs
        @url  = @sqs.interface.queue_url_by_name(url_or_name)
        @name = @sqs.interface.queue_name_by_url(@url)
      end
      
        # Retrieves queue size.
        #
        #  queue.size #=> 1
        #
      def size
        @sqs.interface.get_queue_length(@url)
      end
      
        # Clears queue. 
        # Deletes only the visible messages unless +force+ is +true+.
        #
        #  queue.clear(true) #=> true
        #
        # P.S. when <tt>force==true</tt> the queue deletes then creates again. This is 
        # the quickest method to clear a big queue or a queue with 'locked' messages. All queue
        # attributes are restored. But there is no way to restore grantees' permissions to 
        # this queue. If you have no grantees except 'root' then you have no problems.
        # Otherwise, it's better to use <tt>queue.clear(false)</tt>.
        #
        # PS This function is no longer supported.  Amazon has changed the SQS semantics to require at least 60 seconds between 
        # queue deletion and creation. Hence this method will fail with an exception.
        #
      def clear(force=false)
##        if force
##          @sqs.interface.force_clear_queue(@url)
##        else
          @sqs.interface.clear_queue(@url)
##        end
      end
      
        # Deletes queue. 
        # Queue must be empty or +force+ must be set to +true+. 
        # Returns +true+. 
        #
        #  queue.delete(true) #=> true
        #
      def delete(force=false)
        @sqs.interface.delete_queue(@url, force)
      end

        # Sends new message to queue. 
        # Returns new Message instance that has been sent to queue.
      def send_message(message)
        message = message.to_s
        msg     = Message.new(self, @sqs.interface.send_message(@url, message), message)
        msg.sent_at = Time.now
        msg
      end
      alias_method :push, :send_message

        # Retrieves several messages from queue. 
        # Returns an array of Message instances. 
        #
        #  queue.receive_messages(2,10) #=> array of messages
        #
      def receive_messages(number_of_messages=1, visibility=nil)
        list = @sqs.interface.receive_messages(@url, number_of_messages, visibility)
        list.map! do |entry|
          msg             = Message.new(self, entry[:id], entry[:body], visibility)
          msg.received_at = Time.now 
          msg
        end
      end
      
        # Retrieves first accessible message from queue. 
        # Returns Message instance or +nil+ it the queue is empty.
        #
        #  queue.receive #=> #<RightAws::Sqs::Message:0xb7bf0884 ... >
        #
      def receive(visibility=nil)
        list = receive_messages(1, visibility)
        list.empty? ? nil : list[0]
      end

        # Peeks message body.
        #
        #  queue.peek #=> #<RightAws::Sqs::Message:0xb7bf0884 ... >
        #
      def peek(message_id)
        entry = @sqs.interface.peek_message(@url, message_id)
        msg   = Message.new(self, entry[:id], entry[:body])
        msg.received_at = Time.now 
        msg
      end

        # Pops (and deletes) first accessible message from queue. 
        # Returns Message instance or +nil+ it the queue is empty.
        #
        #  queue.pop #=> #<RightAws::Sqs::Message:0xb7bf0884 ... >
        #
      def pop
        msg = receive
        msg.delete if msg
        msg
      end

        # Retrieves +VisibilityTimeout+ value for the queue. 
        # Returns new timeout value.
        #
        #  queue.visibility #=> 30
        #
      def visibility
        @sqs.interface.get_visibility_timeout(@url)
      end
        
        # Sets new +VisibilityTimeout+ for the queue. 
        # Returns new timeout value. 
        #
        #  queue.visibility #=> 30
        #  queue.visibility = 33
        #  queue.visibility #=> 33
        #
      def visibility=(visibility_timeout)
        @sqs.interface.set_visibility_timeout(@url, visibility_timeout)
        visibility_timeout
      end
        
        # Sets new queue attribute value. 
        # Not all attributes may be changed: +ApproximateNumberOfMessages+ (for example) is a read only attribute. 
        # Returns a value to be assigned to attribute. 
        #
        # queue.set_attribute('VisibilityTimeout', '100')  #=> '100'
        # queue.get_attribute('VisibilityTimeout')         #=> '100'
        #
      def set_attribute(attribute, value)
        @sqs.interface.set_queue_attributes(@url, attribute, value)
        value
      end
        
        # Retrieves queue attributes. 
        # At this moment Amazon supports +VisibilityTimeout+ and +ApproximateNumberOfMessages+ only. 
        # If the name of attribute is set, returns its value. Otherwise, returns a hash of attributes.
        #
        # queue.get_attribute('VisibilityTimeout')  #=> '100'
        #
      def get_attribute(attribute='All')
        attributes = @sqs.interface.get_queue_attributes(@url, attribute)
        attribute=='All' ? attributes : attributes[attribute]
      end
        
        # Retrieves a list of grantees. 
        # Returns an +array+ of Grantee instances if the +grantee_email_address+ is unset. 
        # Otherwise returns a Grantee instance that points to +grantee_email_address+ or +nil+.
        #
        #  grantees = queue.grantees #=> [#<RightAws::Sqs::Grantee:0xb7bf0888 ... >, ...]
        #   ...
        #  grantee  = queue.grantees('cool_guy@email.address') #=> nil | #<RightAws::Sqs::Grantee:0xb7bf0888 ... >
        #
      def grantees(grantee_email_address=nil, permission = nil)
        hash = @sqs.interface.list_grants(@url, grantee_email_address, permission)
        grantees = []
        hash.each do |key, value|
          grantees << Grantee.new(self, grantee_email_address, key, value[:name], value[:perms])
        end
        if grantee_email_address
          grantees.blank? ? nil : grantees.shift
        else
          grantees
        end
      end
    end
    
    
    class Message
      attr_reader   :queue, :id, :body, :visibility
      attr_accessor :sent_at, :received_at
      
      def initialize(queue, id=nil, body=nil, visibility=nil)
        @queue       = queue
        @id          = id
        @body        = body
        @visibility  = visibility
        @sent_at     = nil
        @received_at = nil
      end
      
        # Returns +Message+ instance body.
      def to_s
        @body
      end
      
        # Changes +VisibilityTimeout+ for current message. 
        # Returns new +VisibilityTimeout+ value.
      def visibility=(visibility_timeout)
        @queue.sqs.interface.change_message_visibility(@queue.url, @id, visibility_timeout)
        @visibility = visibility_timeout
      end
      
        # Removes message from queue. 
        # Returns +true+.
      def delete
        @queue.sqs.interface.delete_message(@queue.url, @id)
      end
    end


    class Grantee
      attr_accessor :queue, :id, :name, :perms, :email
      
        # Creates new Grantee instance. 
        # To create new grantee for queue use:
        #
        #   grantee = Grantee.new(queue, grantee@email.address)
        #   grantee.grant('FULLCONTROL')
        #
      def initialize(queue, email=nil, id=nil, name=nil, perms=[])
        @queue = queue
        @id    = id
        @name  = name
        @perms = perms
        @email = email
        retrieve unless id
      end

        # Retrieves security information for grantee identified by email. 
        # Returns +nil+ if the named user has no privileges on this queue, or 
        # +true+ if perms updated successfully. 
      def retrieve # :nodoc:
        @id    = nil
        @name  = nil
        @perms = []
        
        hash = @queue.sqs.interface.list_grants(@queue.url, @email)
        return nil if hash.empty?
        
        grantee = hash.shift
        @id     = grantee[0]
        @name   = grantee[1][:name]
        @perms  = grantee[1][:perms]
        true
      end
        
        # Adds permissions for grantee. 
        # Permission: 'FULLCONTROL' | 'RECEIVEMESSAGE' | 'SENDMESSAGE'. 
        # The caller must have set the email instance variable. 
      def grant(permission=nil)
        raise "You can't grant permission without defining a grantee email address!" unless @email
        @queue.sqs.interface.add_grant(@queue.url, @email, permission)
        retrieve
      end
      
        # Revokes permissions for grantee. 
        # Permission: 'FULLCONTROL' | 'RECEIVEMESSAGE' | 'SENDMESSAGE'. 
        # Default value is 'FULLCONTROL'. 
        # User must have +@email+ or +@id+ set. 
        # Returns +true+.
      def revoke(permission='FULLCONTROL')
        @queue.sqs.interface.remove_grant(@queue.url, @email || @id, permission)
        unless @email   # if email is unknown - just remove permission from local perms list...
          @perms.delete(permission)
        else            # ... else retrieve updated information from Amazon
          retrieve
        end
        true
      end
      
        # Revokes all permissions for this grantee.
        # Returns +true+
      def drop
        @perms.each do |permission|
          @queue.sqs.interface.remove_grant(@queue.url, @email || @id, permission)
        end
        retrieve
        true
      end
      
    end

  end
end
