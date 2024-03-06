NUMBER_OF_DAYS = 30.days

# When run an staging, we don't have data after last friday
# Define the refence as last friday, end of day
current_day_of_week = Time.now.wday
days_to_subtract = ( current_day_of_week - 5 ) % 7
last_friday = ( Time.now - days_to_subtract.days )
at_time = last_friday.utc.end_of_day

# Get users having submitted observations
#
# app_id: 
#   - nil for any application
#   - -1 for web application
#   - or the app id (3=ios, 2=android, 333=seek)
# 
# min_object:
#   minimun number of observations submitted by the user 
#   (to get casual or power users)
#
def active_obs( app_id, min_object, at_time )

    filter = [
        {
            "range": {
                "created_at": {
                    "gte": at_time - NUMBER_OF_DAYS,
                    "lte": at_time
                }
            }
        }
    ]

    if ( app_id == -1 )
        filter << { "bool": { "must_not": { "exists": { "field": "oauth_application_id" } } } }
    elsif ( app_id )
        filter << { "term": { "oauth_application_id": app_id } }
    end

    agg = {
        "user_id": {
            "terms": { 
                "field": "user.id", 
                "size": 10000000 }
        }
    }

    if ( min_object )
        agg[ :user_id ][ :terms ] [ :min_doc_count] = min_object
    end

    return Observation.elastic_search(
        size: 0,
        filters: filter,
        aggregate: agg
    ).response.aggregations.user_id.
        buckets.map { |b| 
            b["key"]
        }

end

# Get users having submitted identifications
#
# min_object:
#   minimun number of identifications submitted by the user 
#   (to get casual or power users)
#
def active_ids( min_object, at_time )

    filter = [
        {
            "range": {
                "created_at": {
                    "gte": at_time - NUMBER_OF_DAYS,
                    "lte": at_time
                    }
                }
            }
        ]

    agg = {
        "user_id": {
            "terms": { 
                "field": "user.id", 
                "size": 10000000 }
        }
    }

    if ( min_object )
        agg[ :user_id ][ :terms ][ :min_doc_count ] = min_object
    end

    return Identification.elastic_search(
        size: 0,
        filters: filter,
        aggregate: agg
    ).response.aggregations.user_id.
        buckets.map { |b| 
            b["key"]
        }

end

# Get metrics for all users, from elastic
all_obs = active_obs( nil, nil, at_time )
all_obs_web = active_obs( -1, nil, at_time )
all_obs_ios = active_obs( 3, nil, at_time )
all_obs_android = active_obs( 2, nil, at_time )
all_obs_seek = active_obs( 333, nil, at_time )
all_ids = active_ids( nil, at_time )
all_users = ( all_obs + all_ids ).uniq

# Get metrics for power users, from elastic
power_obs = active_obs( nil, 10, at_time )
power_obs_web = active_obs( -1, 10, at_time )
power_obs_ios = active_obs( 3, 10, at_time )
power_obs_android = active_obs( 2, 10, at_time )
power_obs_seek = active_obs( 333, 10, at_time )
power_ids = active_ids( 10, at_time )
power_users = ( power_obs + power_ids ).uniq

# Compute metrics for casual users
casual_obs = ( all_obs - power_obs )
casual_obs_web = ( all_obs_web - power_obs_web )
casual_obs_ios = ( all_obs_ios - power_obs_ios )
casual_obs_android = ( all_obs_android - power_obs_android )
casual_obs_seek = ( all_obs_seek - power_obs_seek )
casual_ids = ( all_ids - power_ids )
casual_users = ( casual_obs + casual_ids ).uniq

# Get all active users, from database
all_connected_users = User.where( "last_active >= ?", at_time - NUMBER_OF_DAYS ).pluck( :id )

# Get all new active users, from database
new_connected_users = User.where( "last_active >= ?", at_time - NUMBER_OF_DAYS ).where( "DATE(created_at AT TIME ZONE 'UTC') >= ?", at_time - NUMBER_OF_DAYS ).pluck( :id )

# Compute all existing active users
existing_connected_users = ( all_connected_users - new_connected_users )

# Compute all inactive users (not active)
inactive_users = ( all_connected_users - all_users )

# Prepare results for all users
results_all = {
    active: {
        all: {
            observers: {
                total: all_obs.count, # all users having submitted at least 1 observation
                web: all_obs_web.count, # all users having submitted at least 1 observation using the web application
                ios: all_obs_ios.count, # all users having submitted at least 1 observation using the iOS application
                android: all_obs_android.count, # all users having submitted at least 1 observation using the Android application
                seek: all_obs_seek.count # all users having submitted at least 1 observation using the Seek application
            },
            identifiers: {
                total: all_ids.count # all users having submitted at least 1 identification
            },
            total: all_users.count # all users having submitted at least 1 observation or 1 identification
        },
        power: {
            observers: {
                total: power_obs.count, # all users having submitted at least 10 observations
                web: power_obs_web.count,
                ios: power_obs_ios.count,
                android: power_obs_android.count,
                seek: power_obs_seek.count
            },
            identifiers: {
                total: power_ids.count # all users having submitted at least 10 identifications
            },
            total: power_users.count # all users having submitted at least 10 observations or 10 identifications
        },
        casual: {
            observers: {
                total: casual_obs.count, # all users having submitted between 1 and 10 observations
                web: casual_obs_web.count,
                ios: casual_obs_ios.count,
                android: casual_obs_android.count,
                seek: casual_obs_seek.count
            },
            identifiers: {
                total: casual_ids.count # all users having submitted between 1 and 10 identifications
            },
            total: casual_users.count # all users having submitted between 1 and 10 observations or between 1 and 10 identifications
        },
        total: all_users.count # all users having connected and submitted at least 1 observation or 1 identification 
    },
    inactive: {
        total: inactive_users.count # all users having connected but not submitted any observation or identification 
    },
    total: all_connected_users.count # all users having connected
}

# Prepare results for existing users
# Same as "all users", but restricted to users that created their account more than 30 days ago
results_existing = {
    active: {
        all: {
            observers: {
                total: ( all_obs & existing_connected_users ).count,
                web: ( all_obs_web & existing_connected_users ).count,
                ios: ( all_obs_ios & existing_connected_users ).count,
                android:  (all_obs_android & existing_connected_users ).count,
                seek: ( all_obs_seek & existing_connected_users ).count
            },
            identifiers: {
                total: ( all_ids & existing_connected_users ).count
            },
            total: ( all_users & existing_connected_users ).count
        },
        power: {
            observers: {
                total: ( power_obs & existing_connected_users ).count,
                web: ( power_obs_web & existing_connected_users ).count,
                ios: ( power_obs_ios & existing_connected_users ).count,
                android: ( power_obs_android & existing_connected_users ).count,
                seek: ( power_obs_seek & existing_connected_users ).count
            },
            identifiers: {
                total: ( power_ids & existing_connected_users ).count
            },
            total: ( power_users & existing_connected_users ).count
        },
        casual: {
            observers: {
                total: ( casual_obs & existing_connected_users ).count,
                web: ( casual_obs_web & existing_connected_users ).count,
                ios: ( casual_obs_ios & existing_connected_users ).count,
                android: ( casual_obs_android & existing_connected_users ).count,
                seek: ( casual_obs_seek & existing_connected_users ).count
            },
            identifiers: {
                total: ( casual_ids & existing_connected_users ).count
            },
            total: ( casual_users & existing_connected_users ).count
        },
        total: ( all_users & existing_connected_users ).count
    },
    inactive: {
        total: ( inactive_users & existing_connected_users ).count 
    },
    total: existing_connected_users.count
}

# Prepare results for new users
# Same as "all users", but restricted to users that created their account less than 30 days ago
results_new = {
    active: {
        all: {
            observers: {
                total: ( all_obs & new_connected_users ).count,
                web: ( all_obs_web & new_connected_users ).count,
                ios: ( all_obs_ios & new_connected_users ).count,
                android: ( all_obs_android & new_connected_users ).count,
                seek: ( all_obs_seek & new_connected_users ).count
            },
            identifiers: {
                total: ( all_ids & new_connected_users ).count
            },
            total: ( all_users & new_connected_users ).count
        },
        power: {
            observers: {
                total: ( power_obs & new_connected_users ).count,
                web: ( power_obs_web & new_connected_users ).count,
                ios: ( power_obs_ios & new_connected_users ).count,
                android: ( power_obs_android & new_connected_users ).count,
                seek: ( power_obs_seek & new_connected_users ).count
            },
            identifiers: {
                total: ( power_ids & new_connected_users ).count
            },
            total: ( power_users & new_connected_users ).count
        },
        casual: {
            observers: {
                total: ( casual_obs & new_connected_users ).count,
                web: ( casual_obs_web & new_connected_users ).count,
                ios: ( casual_obs_ios & new_connected_users ).count,
                android: ( casual_obs_android & new_connected_users ).count,
                seek: ( casual_obs_seek & new_connected_users ).count
            },
            identifiers: {
                total: ( casual_ids & new_connected_users ).count
            },
            total: ( casual_users & new_connected_users ).count
        },
        total: ( all_users & new_connected_users ).count
    },
    inactive: {
        total: ( inactive_users & new_connected_users ).count 
    },
    total: new_connected_users.count
}

results = {
    all: results_all,
    existing: results_existing,
    new: results_new
}

results
