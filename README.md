[![Build Status](https://travis-ci.org/declarativesystems/ncedit.svg?branch=master)](https://travis-ci.org/declarativesystems/ncedit)
# ncedit - Puppet Node Classifier CLI editor

ncedit is a small utility program that lets you edit the Puppet Enterprise Node Classifier rules from the command line.

Why would you want to do this given that we have the excellent [node_manager](https://forge.puppet.com/WhatsARanjit/node_manager) module already on the forge?  Well... lots of reasons.  First off, using puppet code to drive the Node Classifier means that you have to have the `node_manager` module already installed, which means that you must already have your [classification rules](https://docs.puppet.com/pe/latest/console_classes_groups_getting_started.html) in to reference the module through [Code Manager](https://docs.puppet.com/pe/latest/code_mgr.html).  You could in-theory use Puppet Enterprise's new idempotent installer (just reinstall puppet over the top of itself) to fix this exact issue but then you still have the problem of how to classify your master in order to activate any other new rules (eg node-ttl) you want to use, which are associated with a new [role](https://docs.puppet.com/pe/latest/r_n_p_intro.html) for the Puppet Master.

That's where this tool comes in since all you need is root shell on the Puppet Master.

## Features
You can:
* Create node groups
* Add or remove classes
* Add or remove class parameters
* Add or remove rules

...All from the convenience of the CLI.  This allows us to be called from scripts and other systems in order to setup Puppet Enterprise the way you want and with the minimum of effort.

You have a choice of running `ncedit` for each change you wish to make or collecting all of your edits into either a JSON or YAML file for bulk processing.

## Installation
Install this tool on your Puppet Master (Master-of-Masters)

```shell
$ sudo /opt/puppetlabs/puppet/bin/gem install ncedit
```
This will install the gem into the Puppet Master's vendored ruby.  You could instead use your OS ruby and it should work, just make sure you have a recent-ish version of ruby.

## Usage

### Node Classifier API access
ncedit is intended to be run on the Puppet Master as root.  Doing so avoids having to deal with networks, firewalls, certificate whitelists and the Puppet Enterprise RBAC API.  While it would be cool to expand the tool to deal with these issues, its just a whole lot simpler to just run from the Puppet Master so right now that's all thats supported.

### Making batch changes
To avoid the need to repeatedly invoke this tool using say, a bash script, ncedit natively supports reading a file of batch changes to make that is written in either YAML or JSON.

#### Batch data file
* Since ncedit internally represents all from the Node Classifier API as hashes, its easy to support both YAML and JSON since they both resolve to this format
* It's possible to add multiple groups at a time, you just need another `NAME_OF_GROUP` stanza

In each case the file needs to be ordered as follows:

##### YAML
```yaml
"NAME_OF_GROUP":
  # hash of classes to edit/create
  "classes":
    "CLASS_TO_ENSURE":
      "OPTIONAL_PARAM_NAME": "VALUE_TO_SET"
  # Array of classes to delete
  "delete_classes":
    - "CLASS_TO_DELETE"
  # Hash classes + Array of parameter names to delete
  "delete_params":
    "CLASS_TO_PROCESS":
      - "PARAMETER_TO_DELETE"
  # Rules to append to group
  "append_rules":
    - "CONDITIONAL" # 'and'/'or'
    - - "="         # rule tuple 0 - comparator, eg '='
      - "VARIABLE"  # rule tuple 1 - variable, eg 'fqdn'
      - "VALUE"     # rule tuple 2 - value to match, eg 'pupper.puppet.com'
```

* [Worked example](doc/example/batch.yaml)

##### JSON
```json
{
  "NAME_OF_GROUP": {
    "classes": {
      "CLASS_TO_ENSURE": {
        "OPTIONAL_PARAM_NAME": "VALUE_TO_SET"
      }
    },
    "delete_classes": [
      "CLASS_TO_DELETE"
    ],
    "delete_params": {
      "CLASS_TO_PROCESS": [
        "PARAMETER_TO_DELETE"
      ]
    },
    "append_rules": [
      "CONDITIONAL",
      [
        "=",
        "VARIABLE",
        "VALUE"
      ]
    ]
  }
}
```

* JSON doesn't support comments natively so please see above YAML example for notes
* [Worked example](doc/example/batch.json)

#### Ensuring changes
* `ncedit` is idempotent so you may run the command as often as you like
* Classes used in rules *must* already exist for classification to succeed, `--smart-update` will do a code redeploy for you if specified.

##### YAML
```shell
ncedit batch --smart-update --yaml-file /path/to/batch.yaml
```

##### JSON
```shell
ncedit batch --smart-update --json-file /path/to/batch.json
```

## Making per-item changes
If you don't want to go to the hassle of creating a batch file or you have small, dynamic edits you wish to perform, your able to perform individual edits on the command line:


### Practical examples
One of the main uses of this tool is to configure Puppet Code Manager, so here are the exact commands you need (alternatively make a `batch.yaml` file to do it all in one hit):

#### Code Manager R10K checkout URL
```shell
ncedit classes --smart-update --group-name 'PE Master' \
    --class-name puppet_enterprise::profile::master \
    --param-name r10k_remote \
    --param-value https://github.com/puppetlabs/control-repo
```

#### Code Manager SSH key
```shell
ncedit classes --smart-update --group-name 'PE Master' \
    --class-name puppet_enterprise::profile::master \
    --param-name r10k_ \
    --param-value /etc/puppetlabs/puppetserver/ssh/id_rsa
```

#### Code Manager proxy server
```shell
ncedit classes --smart-update --group-name 'PE Master' \
    --class-name puppet_enterprise::profile::master \
    --param-name r10k_proxy \
    --param-value http://proxy.megacorp.com:3128
```


#### Enable Code Manager
```shell
ncedit classes --smart-update --group-name 'PE Master' \
    --class-name puppet_enterprise::profile::master \
    --param-name code_manager_auto_configure \
    --param-value true
    
ncedit classes --smart-update --group-name 'PE Master' \
    --class-name puppet_enterprise::profile::master \
    --param-name file_sync_enabled \
    --param-value automatic
```


#### Add a rule to configure the puppet master with extra classes
```shell
ncedit classes --smart-update --group-name "Puppet Masters" \
    --class-name role::my_puppet_master \
    --rule '["and", ["=",["fact","fqdn"],"'$(facter fqdn)'"]]' \
    --rule-mode replace
```

* Run puppet and then re-deploy puppet code
* Create a new group called `Puppet Masters`
* Make it load the role `role::my_puppet_master`
* Have it match any host matching the FQDN of the host the command was run from and replace any existing rules for the group

#### Refresh the list of classes in the console
```shell
ncedit update_classes
```

### Add a class to group
```shell
ncedit classes --group-name FOO --class-name BAR
```
* Group will be created if it doesn't exist
* Class MUST exist AND puppet must be aware of it (defeat caching) for the request to be accepted
* Pass `--smart-update` to run puppet and re-deploy classes if desired

### Add a parameter to a class for a group
```shell
ncedit classes --group-name FOO --class-name BAR --param-name BAZ --param-value BAS
```
* Group will be created if it doesn't exist
* Class will be added if it isn't already
* Class MUST exist AND puppet must be aware of it (defeat caching) AND the parameter must exist on the class for the request to be accepted
* Pass `--smart-update` to run puppet and re-deploy classes if desired

### Delete a parameter from a class inside a group
```shell
ncedit classes --group-name FOO --class-name BAR --param-name BAZ --delete-param
```
* Group will be created if it doesn't exist
* Class will be added if it isn't already
* Ensures the parameter `BAZ` is not set

### Delete a class inside a group
```shell
ncedit classes --group-name FOO --class-name BAR --delete-class
```
* Group will be created if it doesn't exist
* Ensures the class `BAR` is not defined

### Replace all rules for group
```shell
ncedit classes --group-name FOO --rule 'JSON_FRAGMENT' --rule-mode replace
```
* Group will be created if it doesn't exist
* Completely replaces existing rules for this group
* Example JSON_FRAGMENT: `["and",["=",["fact","ipaddress"],"192.168.1.1"]]`

### Append a rule to group
```shell
ncedit classes --group-name FOO --rule 'JSON_FRAGMENT' --rule-mode append
```
* Group will be created if it doesn't exist
* Appends supplied JSON_FRAGMENT to the group's rules
* Example JSON_FRAGMENT: `["and",["=",["fact","osfamily"],"RedHat"]]`
* Notice in our example JSON_FRAGMENT that we have *kept* the outer `and` rule.  If we supply a conjuctive different to the rule's current value we will change it for the whole rule

## Smart updates
The NC API will only accept rules for classes that currently exist on the system, so its likely that your rules will be rejected if they have not yet been deployed to the master.  To make this process as seamless as possible, the `--smart-update` option will perform this task for you as-and-when required.  This assumes you have already setup RBAC to grant access to Code Manager, this can be done in a single command using the [pe_rbac gem](https://github.com/declarativesystems/pe_rbac#setting-up-code-manager-on-the-command-line)

Smart updates work as follows:

* If any of the `r10k_*` or `code_manager_auto_configure` parameters are set, update them immediately
* Run `puppet agent -t` then `puppet-code deploy --all --wait`
* Process any remaining directives

## Troubleshooting
* If you cannot install the `ncedit` gem and you are behind a corporate proxy, ensure that you have correctly set your `http_proxy` and `https_proxy` variables on the shell before running `gem install`.
* Some corporate proxies will attempt to eavesdrop on all SSL connections which will cause downloads to fail.  This can be resolved by installing a CA bundle (be sure you understand the implications of doing so) or domain whitelisting on the proxy itself
* If the ncedit fails, it will swallow stack traces by default, pass the `--verbosity debug` argument if you need to obtain one.  Note the position of the argument before the command name:
```
bundle exec ncedit --verbosity debug  batch --yaml-file /path/to/batch.yaml
```
* Ensure you are running as `root` to avoid permission errors
* If your shell can't find `ncedit` after successful installation and you installed into Puppet Enterprise's vendored ruby, make sure that your `PATH` contains `/opt/puppetlabs/puppet/bin` or run ncedit directly: `/opt/puppetlabs/puppet/bin/ncedit`
* Don't attempt to debug the NC API through the PE console by capturing traffic, it uses a completely different API all of its own (In particular, there is another layer of boolean logic around rules).  Instead, use [NCIO](https://github.com/jeffmccune/ncio) to dump the current state of the NC API or see [Puppet's NC API documentation](https://docs.puppet.com/pe/latest/nc_index.html)

## Testing
To run tests:

```shell
bundle install
bundle exec rake spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/declarativesystems/ncedit.
