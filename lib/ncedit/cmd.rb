module NCEdit
  module Cmd

    def self.rule(options, arguments)
      group_name  = @options[:global][:commands][:rule][:options][:group_name]
      class_name  = @options[:global][:commands][:rule][:options][:class_name]
      param_name  = @options[:global][:commands][:rule][:options][:param_name]
      param_value = @options[:global][:commands][:rule][:options][:param_value]
      delete      = @options[:global][:commands][:rule][:options][:delete]
      puts group_name
      puts class_name
      puts param_name
      puts param_value
      puts delete
    end
  end
end
