[![Build Status](https://travis-ci.org/GeoffWilliams/ncedit.svg?branch=master)](https://travis-ci.org/GeoffWilliams/ncedit)
# ncedit - Puppet Node Classifier CLI editor

ncedit is a small utility program that uses [puppetclassify](https://github.com/puppetlabs/puppet-classify) in order to:
* Create node groups
* Add or remove classes
* Add or remove class parameters
* Add or remove rules

All from the convenience of the CLI.  This also allows this tool to be called from scripts and other systems in order to setup Puppet Enterprise the way you want and with the minimum of effort.

For the moment, the edits to be carried out need to be placed into either a JSON or YAML file for bulk processing.  If there is interest, the tool will be enhanced to allow the above operations to be specified individually on the command line so to avoid the need to write YAML/JSON.

TODO: Delete this and the text above, and describe your gem

## Installation
Install this tool on the same node running the node classification service:

```shell
$ sudo gem install ncedit
Successfully installed ncedit-0.1.0
Parsing documentation for ncedit-0.1.0
Installing ri documentation for ncedit-0.1.0
1 gem installed
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Testing
To run tests:

```shell
bundle install
bundle exec rake spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ncedit.
