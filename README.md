# Logfiction

This gem is log data generator for learning log analysis, simulation, etc...

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'logfiction'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install logfiction

## Usage
```ruby
require 'logfiction'

la = Logfiction::AccessLog.new()

# generate 10000 row fiction log!
logs = la.generate_accesslog(n=10000)

#=> [{:timestamp=>2018-06-29 09:04:08 +0900,
#     :user_id=>54,
#     :state_id=>2,
#     :items=>[23],
#     :state_name=>"detail_page_view"},
#    {:timestamp=>2018-06-29 09:04:09 +0900,
#     :user_id=>23,
#     :state_id=>0,
#     :items=>[],
#     :state_name=>"top_page_view"},
#    {:timestamp=>2018-06-29 09:04:10 +0900,
#     :user_id=>36,
#     :state_id=>1,
#     :items=>[30, 31, 32, 33, 34, 35, 36, 37, 38, 39],
#     :state_name=>"list_page_view"},
#    ...

# CSV Output
la.export_logfile(filetype='CSV',filepath='/path/to/file')

#  => timestamp,user_id,state_id,items,state_name
#     2018-06-29 11:18:58 +0900,47,2,65,detail_page_view
#     2018-06-29 11:18:59 +0900,66,0,"",top_page_view
#     2018-06-29 11:19:02 +0900,64,1,50:51:52:53:54:55:56:57:58:59,list_page_view
#     2018-06-29 11:19:11 +0900,12,3,89,item_purchase
#     2018-06-29 11:19:12 +0900,12,0,"",top_page_view
```

## Advanced Usage
```ruby
require 'logfiction'

assumtions = {
    # Set the log start time to January 01, 2018 AM 9:00 AM
    time_access_from: Time.parse("2018-01-01 09:00:00"),
    
    # Set session limit to 20
    user_max_sessions: 20,

    # Set action limit to 200
    user_max_actions: 100,

    # Set the number of generated users to 500
    n_users: 500,

    # Set the number of generated items to 200
    n_items: 200
}

la = Logfiction::AccessLog.new(assumtions)

# State and transition settings
states = [
    {state_id: 0, state_name: 'top_page_view', item_type: :no_item},
    {state_id: 1, state_name: 'list_page_view', item_type: :many},
    {state_id: 2, state_name: 'detail_page_view', item_type: :one},
    {state_id: 3, state_name: 'item_purchase', item_type: :one}
]

transitions = [
    {from: 0, to: 1, probability: 0.6, restriction: false},
    {from: 1, to: 2, probability: 0.4, restriction: true},
    {from: 2, to: 3, probability: 0.2, restriction: true, auto_transiton: 0}
]

states_transtions = {
    start_state: [0],
    states: states,
    transitions: transitions
}

la.generate_state_transiton(states_transtions)

# get logs
logs = la.generate_accesslog(100)

# export logs
la.export_logfile(100, filetype='CSV',filepath="./fictionlog.csv")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/logfiction. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Logfiction project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/logfiction/blob/master/CODE_OF_CONDUCT.md).
