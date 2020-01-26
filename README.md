# hako-github_status

[hako](https://github.com/eagletmt/hako) script to update image tag of `app` container to the commit SHA of the latest check-succeeded commit in a specified GitHub repository and branch


## Installation

```ruby
gem 'hako-github_status'
```

## Usage

``` jsonnet
{
  scripts: [
    {
      type: 'github_status_tag',
      repo: 'sorah/hello-container',
      ref: 'master',
      # at least either from checks or statuses must be set
      checks: ['ci/circleci:build'], # Required status names on GitHub Checks API
      statuses: ['legacy-ci'], # Required status contexts on GitHub Status API

      client: {
        access_token: 'your-access-token', # or environment variable $OCTOKIT_ACCESS_TOKEN
        # login: 'github-login',
        # password: 'github-password',
        # api_endpoint: 'https://githubenterprise/api/v3/',
        # web_endpoint: 'https://githubenterprise/',

        # Or authenticating as a GitHub app
        # github_app: { private_key: "... PEM ...", app_id: 123456 },
      }
    },
  ],
}
```

```
hako deploy --tag github your-app.jsonnet
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/hako-github_status.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
