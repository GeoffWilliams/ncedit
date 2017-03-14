require 'puppetclassify'
require 'yaml'

module NCEdit
  module Cmd

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
              puts "Classifier signs of life detected, proceeding to classify..."
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              puts "connection refused, waiting..."
              sleep(1)
            end
          end
        end

        puppetclassify = PuppetClassify.new(rest_api_url, auth_info)
      end
    end


    def self.nc_group(group_name)

      # Get the wanted group from the API
      #   1. Get the id of the wanted group
      #   2. Use the id to fetch the group
      group_id  = @puppetclassify.groups.get_group_id(group_name)
      group     = @puppetclassify.groups.get_group(group_id)

      group
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
    #   'append_rule':
    #     - - "="
    #       - "name"
    #       - "vmpump02.puppet.com"
    def self.batch(filename)
      if File.exists?(filename)
        yaml = YAML.load_file(filename)

        yaml.each { |group_name, data|
          puts "Processing #{group_name}"
          delete_classes(group_name, data.dig("delete_classes"))
          delete_params(group_name, data.dig("delete_params"))
          ensure_classes_and_params(group_name, data.dig("classes"))
          ensure_rules(group_name, data.dig("rules"))
        }
      else
        raise "File not found: #{filename}"
      end
    end

        #   if data.has_key?('classes')
        #     data["classes"].each { |class_name
        #       # update each listed class for this group
        #       input = {}
        #       input[:group_name] = group_name
        #
        #       input[:classes] = data["classes"]
        #       if data.dig('delete_classes', class_name)
        #         # delete this class if its in our list of classes to delete.  We
        #         # process the list of classes to delete later on but this is to
        #         # avoid conflicts where users tell us to both create and delete
        #         # the same class in the same file.  Same goes for parameters
        #         input[:delete_class] = true
        #
        #         # remove the class from the delete_classes hash to avoid double
        #         # handling
        #         data[:delete_class].delete(class_name)
        #       else
        #         if data[:classes][class_name] != nil
        #           # There are class paramers...
        #           data[:classes][class_name].each { |param_name, param_value|
        #             input[:param_name] = param_name
        #             if data.dig('delete_params', param_name)
        #               input[:delete_param] = true
        #               data[:delete_params].delete(param_name)
        #             else
        #
        #           }
        #         end
        #       end
        #     }
        #
        #   end
        # }


    def self.ensure_classes(input)
      if input[:group_name] == nil
        raise "group-name is required"
      end

      if input[:class_name] == nil
        raise "class-name is required"
      end

      puppetclassify = initialize_puppetclassify

      # Get the wanted group from the API
      #   1. Get the id of the wanted group
      #   2. Use the id to fetch the group
      group_id  = puppetclassify.groups.get_group_id(input[:group_name])
      group     = puppetclassify.groups.get_group(group_id)

      changes = false
      if input[:delete_class]
        # delete class if we are supposed to
        if group["classes"].delete(input[:class_name])
          changes = true
        end
      else
        # ensure wanted class exists
        if ! group["classes"].has_key?(input[:class_name])
          group["classes"][input[:class_name]] = {}
          changes = true
        end

        if input[:delete_param]
          # remove parameter if we are supposed to
          if group["classes"][input[:class_name]].delete(input[:param_name])
            changes = true
          end
        elsif input[:param_name]
          # ensure parameter set if specified
          if ! group["classes"][input[:class_name]].has_key?(input[:param_name]) or
              group["classes"][input[:class_name]][input[:param_name]] != input[:param_value]
            group["classes"][input[:class_name]][input[:param_name]] = input[:param_value]
            changes = true
          end
        end
      end

      # Build the hash to pass to the API
      if changes
        group_delta = {
          'id'      => group_id,
          'rule'    => group["rule"],
          'classes' => group["classes"]
        }
        puppetclassify.groups.update_group(group_delta)
        puts "changes saved"
      else
        puts "already up-to-date"
      end
    end

    def self.classes(options, arguments)
      csv_file = options[:global][:commands][:classes][:options][:csv]
      if csv_file
        # parse csv file into an array of class settings to add
        input = parse_csv(csv_file)
      else
        # Input is a single array element with the options in it
        input = [options[:global][:commands][:classes][:options]]
      end

      group_name    = options[:global][:commands][:classes][:options][:group_name]
      class_name    = options[:global][:commands][:classes][:options][:class_name]
      param_name    = options[:global][:commands][:classes][:options][:param_name]
      param_value   = options[:global][:commands][:classes][:options][:param_value]
      delete_class  = options[:global][:commands][:classes][:options][:delete_class]
      delete_param  = options[:global][:commands][:classes][:options][:delete_param]

      if group_name == nil
        raise "group-name is required"
      end

      if class_name == nil
        raise "class-name is required"
      end

      puppetclassify = initialize_puppetclassify

      # Get the wanted group from the API
      #   1. Get the id of the wanted group
      #   2. Use the id to fetch the group
      group_id  = puppetclassify.groups.get_group_id(group_name)
      group     = puppetclassify.groups.get_group(group_id)

      changes = false
      # if delete_class
        # # delete class if we are supposed to
        # if group["classes"].delete(class_name)
        #   changes = true
        # end
      # else
        # ensure wanted class exists
        # if ! group["classes"].has_key?(class_name)
        #   group["classes"][class_name] = {}
        #   changes = true
        # end

        # if delete_param
          # remove parameter if we are supposed to
          # if group["classes"][class_name].delete(param_name)
          #   changes = true
          # end
        # elsif param_name
        #   # ensure parameter set if specified
        #   if ! group["classes"][class_name].has_key?(param_name) or
        #       group["classes"][class_name][param_name] != param_value
        #     group["classes"][class_name][param_name] = param_value
        #     changes = true
        #   end
        # end
      # end

      # Build the hash to pass to the API
      if changes
        group_delta = {
          'id'      => group_id,
          'rule'    => group["rule"],
          'classes' => group["classes"]
        }
        puppetclassify.groups.update_group(group_delta)
        puts "changes saved"
      else
        puts "already up-to-date"
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
      if group["classes"][class_name].delete(param_name)
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
          puts "Deleting class: #{group_name}->#{class_name}"
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
            puts "Deleting param: #{group_name}->#{class_name}=>#{param_name}"
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
          puts "ensuring class: #{group_name}->#{class_name}"
          updated |= ensure_class(nc_group(group_name), class_name)
          if params
            params.each { |param_name, param_value|
              puts "ensuring param: #{group_name}->#{class_name}->#{param_name}=#{param_value}"
              updated |= ensure_param(nc_group(group_name), class_name, param_name, param_value)
            }
          end
        }
      end
      updated
    end

    def self.ensure_rule(group, rule)
      updated = false
      if ! group["rules"]
        # no rules yet - just add our new one
        group["rules"] = []
      end

      # see if rule already exists, if it doesn't, append it
      found = false
      group["rules"].each {|system_rule|
        if  system_rule[0] == rule[0] and
            system_rule[1] == rule[1] and
            system_rule[2] == rule[2]
            # rule found
            found = true
        end
      }
      if ! found
        puts "Appending rule: #{rule}"
        group["rules"] << rule
        updated = true
      end

      updated
    end

    def self.ensure_rules(group_name, rules)
      updated = false
      rules.each { |rule|
        updated |= ensure_rule(nc_group(group_name), rule)
      }

      updated
    end
  end
end
