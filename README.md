# Faraday::Middlewares::BuildService

Provides a Faraday Middleware to interact with the [Open Build Service][obs].

It'll automatically retry a request with the authentication mechanism requested by the Build Service.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
$ bundle add faraday-middlewares-bs-auth
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
$ gem install faraday-middlewares-bs-auth
```

## Usage

```ruby
# For Basic Authentication
credentials = {
    username: 'my-user',
    password: 'my-password'
}

# For SSH Signature authentication
credentials = {
    username: 'my-user',
    ssh_key: '--- BEGIN ... KEY --- ...'
}

base_url = "https://build.opensuse.org/"

client = Faraday.new(url: base_url) do |faraday|
    faraday.use FaradayMiddleware::FollowRedirects
    faraday.use Faraday::BuildService::Authentication, credentials: credentials
end

# then use faraday as usual:
response = client.get('/about')
puts response.headers
puts response.body
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SUSE/faraday-middlewares-build_service. This project is intended to be a safe, welcoming space for collaboration.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

[obs]: https://openbuildservice.org/
