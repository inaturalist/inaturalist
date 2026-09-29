# frozen_string_literal: true

class VirtuousService
  GIFT_QUERY_ENDPOINT = "https://api.virtuoussoftware.com/api/Gift/Query"
  FULL_CONTACT_ENDPOINT = "https://api.virtuoussoftware.com/api/Contact/Query/FullContact"
  FULL_GIFT_QUERY_ENDPOINT = "https://api.virtuoussoftware.com/api/Gift/Query/FullGift"
  POTENTIAL_ERRORS = [
    Timeout::Error,
    RestClient::ServiceUnavailable,
    RestClient::GatewayTimeout,
    RestClient::TooManyRequests,
    RestClient::InternalServerError,
    RestClient::BadGateway,
    RestClient::Exceptions::Timeout
  ].freeze

  def initialize( options = {} )
    @after_date = options[:after_date]
    @dry_run = options[:dry_run]
    @debug = options[:debug]
  end

  def fetch_donors
    @total_verified_users = 0
    @new_verified_users = 0
    @new_verified_user_parents = 0
    @failed_users = 0
    @failed_parents = 0
    @user_donations = 0
    @donors = {}

    @start_time = Time.now
    last_gift_id = nil
    loop do
      last_gift_id = fetch_donors_loop( last_gift_id )
      break if last_gift_id.nil?
    end

    return unless @debug

    puts
    puts "#{@donors.size} donors, #{@total_verified_users} donor users, " \
      "#{@new_verified_users} new donor users, #{@new_verified_user_parents} new " \
      "donor parents, #{@failed_users} failed users, #{@failed_parents} failed " \
      "parents, #{@user_donations} user donations in " \
      "#{( Time.now - @start_time ).round( 2 )}s"
    puts
  end

  def fetch_donors_loop( last_gift_id )
    batch_gifts_list = fetch_gifts_batch( last_gift_id )
    if batch_gifts_list.empty?
      return nil
    end

    contact_ids = batch_gifts_list.map {| gift | gift["contactId"] }.uniq
    batch_contacts_list = fetch_contacts( contact_ids )
    gift_additional_contacts, additional_contacts = lookup_passthrough_contacts(
      batch_gifts_list, batch_contacts_list
    )
    batch_contacts_list += additional_contacts

    contact_inaturalist_users, contact_user_parents = lookup_contact_users( batch_contacts_list )
    apply_donations_to_users(
      batch_gifts_list,
      contact_inaturalist_users,
      contact_user_parents,
      gift_additional_contacts
    )

    # return the last gift ID to be used for the next batch query
    batch_gifts_list.last["id"]
  end

  def fetch_gifts_batch( last_gift_id )
    conditions = []
    if @after_date
      conditions << {
        parameter: "Last Modified Date",
        operator: "GreaterThan",
        value: @after_date
      }
    end
    if last_gift_id
      conditions << {
        parameter: "Gift Id",
        operator: "GreaterThan",
        value: last_gift_id
      }
    end
    post_body = {
      groups: [{
        conditions: conditions
      }],
      sortBy: "Id",
      descending: "false"
    }
    url = "#{VirtuousService::GIFT_QUERY_ENDPOINT}?take=1000"
    response_body = fetch_api_post_response( url, post_body )
    if response_body.empty?
      return []
    end

    if @debug
      puts "Total results: #{response_body['total']}"
      puts "Run time: #{( Time.now - @start_time ).round( 2 )}s"
      puts
    end
    response_body["list"]
  end

  def fetch_contacts( contact_ids )
    if contact_ids.empty?
      return []
    end

    post_body = {
      groups: [],
      sortBy: "Id",
      descending: "false"
    }
    contact_ids.each do | contact_id |
      post_body[:groups] << {
        conditions: [{
          parameter: "Contact Id",
          operator: "Is",
          value: contact_id
        }]
      }
    end
    url = "#{VirtuousService::FULL_CONTACT_ENDPOINT}?take=1000"
    response_body = fetch_api_post_response( url, post_body, long_post_body: true )
    if response_body.empty?
      return []
    end

    response_body["list"]
  end

  def lookup_passthrough_contacts( batch_gifts_list, batch_contacts_list )
    non_household_contacts = batch_contacts_list.filter do | contact |
      contact["contactType"] != "Household"
    end
    non_household_contact_ids = non_household_contacts.map {| contact | contact["id"] }
    non_household_gifts = batch_gifts_list.filter do | gift |
      non_household_contact_ids.include?( gift["contactId"] )
    end
    non_household_gift_ids = non_household_gifts.map {| gift | gift["id"] }
    return [{}, []] if non_household_gift_ids.empty?

    post_body = {
      groups: [],
      sortBy: "Id",
      descending: "false"
    }
    non_household_gift_ids.each do | gift_id |
      post_body[:groups] << {
        conditions: [{
          parameter: "Gift Id",
          operator: "Is",
          value: gift_id
        }]
      }
    end
    url = "#{VirtuousService::FULL_GIFT_QUERY_ENDPOINT}?take=1000"
    response_body = fetch_api_post_response( url, post_body, long_post_body: true )
    if response_body.empty?
      return [{}, []]
    end

    gift_additional_contacts = {}
    response_body["list"].each do | full_gift |
      next unless full_gift["giftPassthroughs"].is_a?( Array )

      gift_id = full_gift["id"]
      full_gift["giftPassthroughs"].each do | gift_passthrough |
        gift_additional_contacts[gift_id] ||= []
        gift_additional_contacts[gift_id] << gift_passthrough["contactId"]
      end
    end

    additional_contact_ids = gift_additional_contacts.values.flatten.uniq.compact
    [gift_additional_contacts, fetch_contacts( additional_contact_ids )]
  end

  def lookup_contact_users( contacts_list )
    contact_inaturalist_users = {}
    contact_user_parents = {}
    contacts_list.each do | contact |
      contact_id = contact["id"]
      contact["contactIndividuals"]&.each do | individual |
        individual["contactMethods"]&.each do | contact_method |
          next unless contact_method["type"]&.downcase&.include?( "email" )
          next unless contact_method["value"]&.include?( "@" )

          if ( inaturalist_user = User.find_by_email( contact_method["value"].downcase ) )
            contact_inaturalist_users[contact_id] ||= []
            contact_inaturalist_users[contact_id] << inaturalist_user
            if inaturalist_user.parentages.length.positive?
              contact_user_parents[contact_id] ||= []
              contact_user_parents[contact_id] += inaturalist_user.parentages
            end
          end
          user_parents = UserParent.where( email: contact_method["value"].downcase )
          if user_parents.length.positive?
            contact_user_parents[contact_id] ||= []
            contact_user_parents[contact_id] += user_parents
          end
        end
      end
    end

    [contact_inaturalist_users, contact_user_parents]
  end

  def apply_donations_to_users(
    batch_gifts_list, contact_inaturalist_users, contact_user_parents,
    gift_additional_contacts
  )
    batch_gifts_list.each do | gift |
      gift_id = gift["id"]
      contact_ids = [gift["contactId"]]
      if gift_additional_contacts[gift_id]
        contact_ids = ( contact_ids + gift_additional_contacts[gift_id] ).uniq
        puts "Gift: #{gift['id']}; Contacts: #{contact_ids}" if @debug
      end
      contact_ids.each do | contact_id |
        @donors[contact_id] = true
        contact_inaturalist_users[contact_id]&.uniq&.each do | user |
          puts "\tDonor: #{user.donor?}" if @debug
          if user.virtuous_donor_contact_id.blank?
            if @dry_run || user.update( virtuous_donor_contact_id: contact_id )
              puts "\tMarked #{user} as a donor" if @debug
              @new_verified_users += 1
            else
              if @debug
                puts "Failed to mark #{user} as a donor: #{user.errors.full_messages.to_sentence}"
              end
              @failed_users += 1
            end
          end
          @total_verified_users += 1

          gift_date = Date.strptime( gift["giftDate"], "%m/%e/%Y" )
          next if UserDonation.where( user: user ).where( "DATE(donated_at) = ?", gift_date ).exists?

          puts "\tAdding donation for #{user} on #{gift['giftDate']}" if @debug
          unless @dry_run
            UserDonation.create( user: user, donated_at: gift_date )
          end
          @user_donations += 1
        end

        contact_user_parents[contact_id]&.uniq&.each do | user_parent |
          next unless user_parent.virtuous_donor_contact_id.blank?

          begin
            if @dry_run || user_parent.update( virtuous_donor_contact_id: contact_id )
              puts "\tMarked #{user_parent} as a donor" if @debug
              @new_verified_user_parents += 1
            else
              if @debug
                puts "Failed to mark #{user_parent} as a donor: #{user_parent.errors.full_messages.to_sentence}"
              end
              @failed_parents += 1
            end
          rescue OpenSSL::SSL::SSLError, Net::ReadTimeout => e
            # Mail failed to send
            if @debug
              puts "Failed to mark #{user_parent} as a donor: mail delivery failed (#{e})"
            end
            @failed_parents += 1
          end
        end
      end
    end
  end

  def fetch_api_post_response( url, post_body, options = {} )
    if @debug
      if options[:long_post_body]
        puts "Calling #{url} with long post body"
      else
        puts "Calling #{url} with:"
        pp post_body
      end
    end

    response = try_and_try_again( VirtuousService::POTENTIAL_ERRORS, exponential_backoff: true, sleep: 3 ) do
      RestClient::Request.execute(
        url: url,
        method: :post,
        payload: post_body.to_json,
        headers: {
          Authorization: "Bearer #{CONFIG.virtuous.token}",
          "Content-Type": "application/json",
          Accept: "application/json"
        },
        timeout: 120
      )
    end

    if response&.code != 200
      return []
    end

    puts "Ratelimit remaining: #{response.headers[:x_ratelimit_remaining]}" if @debug
    response_body = JSON.parse( response.body )
    unless response_body&.key?( "total" )
      return []
    end

    response_body
  end
end
