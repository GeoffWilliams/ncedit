require 'puppetclassify'
require 'yaml'
require 'escort'

module NCEdit
  module Cmd
    DEFAULT_RULE = "or"

    def self.init(puppetclassify = nil)
      if puppetclassify
        # use passed in puppetclassify if present - allows injection for easy
        # tesing - otherwise make a real one
        @puppetclassify = puppetclassify
      else
        hostname = %x(facter fqdn).strip.downcase
        port = 4433

        # Define the url to the classifier API - we can't just do localhost because
        # the name has to match the SSL certificate
        rest_api_url = "https://#{hostname}:#{port}/classifier-api"

        # We need to authenticate against the REST API using a certificate
        # that is whitelisted in /etc/puppetlabs/console-services/rbac-certificate-whitelist.
        # (https://docs.puppetlabs.com/pe/latest/nc_forming_requests.html#authentication)
        #
        # Since we're doing this on the master,
        # we can just use the internal dashboard certs for authentication
        ssl_dir     = '/etc/puppetlabs/puppet/ssl'
        ca_cert     = "#{ssl_dir}/ca/ca_crt.pem"
        cert_name   = hostname.downcase
        cert        = "#{ssl_dir}/certs/#{cert_name}.pem"
        private_key = "#{ssl_dir}/private_keys/#{cert_name}.pem"

        auth_info = {
          'ca_certificate_path' => ca_cert,
          'certificate_path'    => cert,
          'private_key_path'    => private_key,
        }

        # wait upto 5 mins for classifier to become live...
        port_open = false
        Timeout::timeout(300) do
          while not port_open
            begin
              s = TCPSocket.new(hostname, port)
              s.close
              port_open = true
              Escort::Logger.output.puts "Classifier signs of life detected, proceeding to classify..."
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              Escort::Logger.output.puts "connection refused, waiting..."
              sleep(1)
            end
          end
        end

        @puppetclassify = PuppetClassify.new(rest_api_url, auth_info)
      end
    end

    # Fetch a group by ID, make the group if it doesn't already exist
    def self.nc_group_id(group_name)
      if ! @puppetclassify
        init
      end

      group_id  = @puppetclassify.groups.get_group_id(group_name)
      if group_id == nil
        Escort::Logger.output.puts "Group: #{group_name} does not exist, creating..."
        res = @puppetclassify.groups.create_group(
          {
            "name"    => group_name,
            "parent"  => @puppetclassify.groups.get_group_id("All Nodes"),
            "classes" => {},
          }
        )
        if res == nil
          raise "Error creating group #{group_name}"
        end

        # re-fetch the group id
        group_id  = @puppetclassify.groups.get_group_id(group_name)
      end

      group_id
    end

    def self.nc_group(group_name)
      if ! @puppetclassify
        init
      end
      # Get the wanted group from the API
      #   1. Get the id of the wanted group
      #   2. Use the id to fetch the group
      group_id  = nc_group_id(group_name)
      Escort::Logger.output.puts "Group #{group_name} found, getting definition"
      group = @puppetclassify.groups.get_group(group_id)

      group
    end

    def self.update_group(group_name, classes: nil, rule: nil)
      # group_delta will actually replace all classes/rules with whatever is
      # specified, so we need to merge this with any existing definition if
      # one of these fields is not needed for a particular update otherwise
      # updating just the classes would remove the current rule!
      if classes == nil
        classes = nc_group(group_name)["classes"]
      end

      if rule == nil
        rule = nc_group(group_name)["rule"]
      end

      group_delta = {
        'id'      => nc_group_id(group_name),
        'rule'    => rule,
        'classes' => classes,
      }
      res = @puppetclassify.groups.update_group(group_delta)

      # due to the way the puppetclassify gem is written, we get a nil response
      # on every request, whether it passed or failed.  Therefore, to test that
      # our update was processed correctly, the only thing we can do is to fetch
      # the group again from puppetclassify and check that all of our values are
      # now present.  If there was an error, then the user should have
      # previously seen some output since puppetclassify prints some useful
      # debug output
      saved_group = nc_group(group_name)
      if saved_group["classes"] == classes and saved_group["rule"] == rule
        Escort::Logger.output.puts "changes saved"
      else
        Escort::Logger.error.error "re-read #{group_name} results in #{saved_group} should have delta of #{group_delta}"
        raise "Error saving #{group_name}"
      end
    end

    # Batch entry from YAML file, example file format:
    # 'PE Master':
    #   'classes':
    #     'puppet_enterprise::profile::master':
    #       'r10k_remote': 'http://blah'
    #       'r10k_private_key': '/etc/topsecret'
    #
    #   'delete_classes':
    #      'puppet_enterprise::profile::masterbad'
    #
    #   'delete_params':
    #      'puppet_enterprise::profile::redo:
    #         'badparam'
    #
    # 'Puppet Masters':
    #   'clases':
    #     'role::puppet::master':
    #   'append_rules':
    #     - - "="
    #       - "name"
    #       - "vmpump02.puppet.com"
    def self.batch(filename)
      if File.exists?(filename)
        begin
          yaml = YAML.load_file(filename)

          yaml.each { |group_name, data|
            Escort::Logger.output.puts "Processing #{group_name}"

            if data.has_key?("delete_classes")
              if delete_classes(group_name, data["delete_classes"])
                update_group(group_name, classes: data["delete_classes"])
              end
            end

            if data.has_key?("delete_params")
              if delete_params(group_name, data["delete_params"])
                update_group(group_name, classes: data["delete_params"])
              end
            end

            if data.has_key?("classes")
              if ensure_classes_and_params(group_name, data["classes"])
                update_group(group_name, classes: data["classes"])
              end
            end

            if data.has_key?("append_rules")
              puts "XXXXXXXXXXXXXXX #{data}"
              if ensure_rules(group_name, data["append_rules"])

                update_group(group_name, rule: data["append_rules"])
              end
            end
          }
        rescue Psych::SyntaxError
          Escort::Logger.error.error "Syntax error found in #{filename}, please fix and retry"
        end
      else
        Escort::Logger.error.error "File not found: #{filename}"
      end
    end

    def self.delete_class(group, class_name)
      if group["classes"].delete(class_name)
        changes = true
      else
        changes = false
      end

      changes
    end

    def self.delete_param(group, class_name, param_name)
      if  group["classes"].has_key?(class_name) and
          group["classes"][class_name].delete(param_name)
        changes = true
      else
        changes = false
      end
      changes
    end

    def self.ensure_class(group, class_name)
      if ! group["classes"].has_key?(class_name)
        group["classes"][class_name] = {}
        changes = true
      else
        changes = false
      end

      changes
    end

    def self.ensure_param(group, class_name, param_name, param_value)
      # ensure parameter set if specified
      if ! group["classes"][class_name].has_key?(param_name) or
          group["classes"][class_name][param_name] != param_value
        group["classes"][class_name][param_name] = param_value
        changes = true
      else
        changes = false
      end

      changes
    end

    def self.delete_classes(group_name, data)
      updated = false
      if data
        data.each{ |class_name|
          Escort::Logger.output.puts "Deleting class: #{group_name}->#{class_name}"
          updated |= delete_class(nc_group(group_name), class_name)
        }
      end
      updated
    end

    def self.delete_params(group_name, data)
      updated = false
      if data
        data.each{ |class_name, param_names|
          param_names.each { |param_name|
            Escort::Logger.output.puts "Deleting param: #{group_name}->#{class_name}=>#{param_name}"
            updated |= delete_param(nc_group(group_name), class_name, param_name)
          }
        }
      end
      updated
    end

    def self.ensure_classes_and_params(group_name, data)
      updated = false
      if data
        data.each{ |class_name, params|
          Escort::Logger.output.puts "ensuring class: #{group_name}->#{class_name}"
          updated |= ensure_class(nc_group(group_name), class_name)
          if params
            params.each { |param_name, param_value|
              Escort::Logger.output.puts "ensuring param: #{group_name}->#{class_name}->#{param_name}=#{param_value}"
              updated |= ensure_param(nc_group(group_name), class_name, param_name, param_value)
            }
          end
        }
      end
      updated
    end

    # Ensure a partualar rule exists in the group["rule"] array
    # This affects only the items in the chain, eg:
    # [
    #  "or",
    #   [
    #     <--- here!
    #   ]
    # ]
    #
    # Only the rule to be added in should be passed as the rule parameter, eg:
    # ["=", "name", "bob"]
    def self.ensure_rule(group, rule)
      updated = false

      # see if rule already exists, if it doesn't, append it
      found = false

      # rules are nested like this, the "or" applies to the whole rule chain:
      # "rule"=>["or", ["=", "name", "bob"], ["=", "name", "hello"]]
      group["rule"][1].each {|system_rule|
        if  system_rule[0] == rule[0] and
            system_rule[1] == rule[1] and
            system_rule[2] == rule[2]
            # rule found
            found = true
        end
      }
      if ! found
        Escort::Logger.output.puts "Appending rule: #{rule}"
        group["rule"][1] << rule
        updated = true
      end
puts "ZZZZZZZZZZZ #{group["rule"]}"
      updated
    end

    # rules need to arrive like this:
    # ["or", ["=", "name", "pupper.megacorp.com"], ["=", "name", "pupper.megacorp.com"]]
    # since the rule conjunction "or" can only be specified once per rule chain
    # we will replace whatever already exists in the rule with what the user
    # specified
    def self.ensure_rules(group_name, rules)
      updated = false
      group = nc_group(group_name)
      if ! group["rule"] or group["rule"].empty?
        # no rules yet - just add our new one
        group["rule"] = [DEFAULT_RULE,[]]
        puts "DEFAULT RULE ADDED"
      end
      puts "rulezzzzzzzzzzz #{rules}"
      updated |= ensure_rule_conjunction(group, rules[0])
      rules[1].each { |rule|
        updated |= ensure_rule(group, rule)
      }

      updated
    end

    def self.ensure_rule_conjunction(group, op)
      updated = false
      puts "op <<<<#{op}"
      if ["and", "or"].include?(op)
        if group["rule"][0] != op
          group["rule"][0] = op
          updated = true
        end
      else
        raise "Illegal rule conjunction #{op}, allowed: 'and', 'or'"
      end

      updated
    end
  end
end
