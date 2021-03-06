class Chef
  class Knife
    module Core
      # Instances of BootstrapContext are the context objects (i.e., +self+) for
      # bootstrap templates. For backwards compatability, they +must+ set the
      # following instance variables:
      # * @config   - a hash of knife's config values
      # * @run_list - the run list for the node to boostrap
      #
      class BootstrapContext

        def validation_key
          @chef_config[:validation_key_content]
        end

        def start_chef
          # If the user doesn't have a client path configure, let bash use the PATH for what it was designed for
          client_path = @chef_config[:chef_client_path] || 'chef-client'
          s = "#{client_path} "
          s << ' -l debug' if @config[:verbosity] and @config[:verbosity] >= 2
          s << " -E #{bootstrap_environment}"
          s
        end

        def config_content
          client_rb = ""

          client_rb << <<-CONFIG
log_level        :info
log_location     "#{@config[:log_location]}/chef-client.log"
chef_server_url  "#{@chef_config[:chef_server_url]}"
validation_client_name "#{@chef_config[:validation_client_name]}"
CONFIG
          if @config[:chef_node_name]
            client_rb << %Q{node_name "#{@config[:chef_node_name]}"\n}
          else
            client_rb << "# Using default node name (fqdn)\n"
          end

          if knife_config[:bootstrap_proxy]
            client_rb << %Q{http_proxy        "#{knife_config[:bootstrap_proxy]}"\n}
            client_rb << %Q{https_proxy       "#{knife_config[:bootstrap_proxy]}"\n}
          end

          if knife_config[:bootstrap_no_proxy]
            client_rb << %Q{no_proxy       "#{knife_config[:bootstrap_no_proxy]}"\n}
          end

          if encrypted_data_bag_secret
            client_rb << %Q{encrypted_data_bag_secret "/etc/chef/encrypted_data_bag_secret"\n}
          end

          client_rb << @config[:user_client_rb] + "\r\n" unless @config[:user_client_rb].empty?
          client_rb << <<-CONFIG
# Add support to use chef Handlers for heartbeat and
# status reporting to Azure
require \"chef/azure/chefhandlers/start_handler\"
require \"chef/azure/chefhandlers/report_handler\"
require \"chef/azure/chefhandlers/exception_handler\"

start_handlers << AzureExtension::StartHandler.new(\"#{@config[:chef_extension_root]}\")
report_handlers << AzureExtension::ReportHandler.new(\"#{@config[:chef_extension_root]}\")
exception_handlers << AzureExtension::ExceptionHandler.new(\"#{@config[:chef_extension_root]}\")

CONFIG

          client_rb
        end

      end
    end
  end
end