require 'puppetclassify'

module NCEdit
  module Cmd

    def self.initialize_puppetclassify
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

      # return
      puppetclassify
    end

    def self.classes(options, arguments)
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
      if delete_class
        # delete class if we are supposed to
        if group["classes"].delete(class_name)
          changes = true
        end
      else
        # ensure wanted class exists
        if ! group["classes"].has_key?(class_name)
          group["classes"][class_name] = {}
          changes = true
        end

        if delete_param
          # remove parameter if we are supposed to
          if group["classes"][class_name].delete(param_name)
            changes = true
          end
        elsif param_name
          # ensure parameter set if specified
          if ! group["classes"][class_name].has_key?(param_name) or
              group["classes"][class_name][param_name] != param_value
            group["classes"][class_name][param_name] = param_value
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
        puts group_delta
        puppetclassify.groups.update_group(group_delta)
        puts "changes saved"
      else
        puts "already up-to-date"
      end
    end
  end
end
