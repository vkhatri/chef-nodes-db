#
# Cookbook Name:: rundeck_nodes
# Recipe:: search
#
# Copyright 2014, Virender Khatri
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef'
require 'chef/node'
require 'chef/rest'
require 'chef/role'
require 'chef/environment'
require 'chef/data_bag'
require 'chef/data_bag_item'
require 'resolv'

module RundeckNodes
  # fetch node information into Hash
  class Search
    attr_accessor :options, :environment, :cluster_attribute, :application_attribute, :search_pattern, :ignore_node_error, :username, :file_type

    def initialize(opts = {})
      @options = opts
      @environment = opts[:environment] || fail('missing :environment')
      @cluster_attribute = opts[:cluster_attribute]
      @application_attribute = opts[:application_attribute]
      @search_pattern = opts[:search_pattern] || "chef_environment:#{opts[:environment]}"
      @ignore_node_error = opts[:ignore_node_error]
      @username = opts[:username] || 'rundeck'
      @file_type = opts[:file_type] || 'json'
    end

    def variable_check(var)
      var.to_s.empty? ? false : true
    end

    def environment_resources
      s = Chef::Search::Query.new
      results = s.search('node', search_pattern)[0]
      convert_resources(results)
    end

    def convert_resources(results)
      nodes = {}
      results.each do |node|
        node_hash = convert_node(node)

        begin
          # check node attributes
          validate_node(node_hash)
        rescue => error
          # ignore node if unable to determine all attributes
          unless ignore_node_error
            Chef::Log.warn("#{error.message}, node ignored")
            next
          end
        end

        nodes[node_hash['nodename']] = node_hash
      end

      case file_type
      when 'yaml'
        nodes.to_yaml
      when 'json'
        require 'json'
        JSON.pretty_generate(nodes)
      end
    end

    def convert_node(node)
      # prepare Node Hash object
      node_hash = {}

      # rundeck attributes
      node_hash['nodename'] = node['fqdn']
      # node_hash['name'] = node.name
      node_hash['hostname'] = node['ipaddress']
      node_hash['osVersion'] = node['platform_version']
      node_hash['osFamily'] = node['platform_family']
      node_hash['osName'] = node['paltform']
      node_hash['osArch'] = node['machine']
      node_hash['username'] = username
      node_hash['description'] = nil

      # normal node attributes

      node_hash['machine'] = node['machine']
      node_hash['ipaddress'] = node['ipaddress']
      node_hash['ip6address'] = node['ip6address']
      node_hash['chef_environment'] = node.chef_environment
      node_hash['environment'] = node.chef_environment
      # node_hash['run_list'] = node.run_list
      node_hash['recipes'] = !node.run_list.nil? ? node.run_list.recipes : []
      node_hash['roles'] = !node.run_list.nil? ? node.run_list.roles : []
      node_hash['fqdn'] = node['fqdn']
      node_hash['domain'] = node['domain']
      node_hash['hostname'] = node['hostname']
      node_hash['kernel_machine'] = !node['kernel'].nil? ? node['kernel']['machine'] : nil
      node_hash['kernel_os'] = !node['kernel'].nil? ? node['kernel']['os'] : nil
      node_hash['kernel_release'] = !node['kernel'].nil? ? node['kernel']['release'] : nil
      node_hash['os'] = node['os']
      node_hash['platform'] = node['platform']
      node_hash['platform_version'] = node['platform_version']
      node_hash['tags'] = node['tags'].to_a.flatten
      node_hash['disks'] = node['filesystem'].map { |d, o| d if d.to_s =~ /^\/dev/ && o['fs_type'] != 'swap' && o.key?('mount') }.compact if node['filesystem']
      node_hash['memory'] = node['memory'] && node['memory']['total'] ? (node['memory']['total'].gsub(/\D/, '').to_i / 1024).to_i : 0
      node_hash['cpu'] = node['cpu'] ? node['cpu']['total'] : 0

      if node.key?('ec2')
        node_hash['node_region'] = node['ec2']['placement_availability_zone'].chop
        node_hash['node_id'] = node['ec2']['instance_id']
        node_hash['node_type'] = node['ec2']['instance_type']
        node_hash['node_zone'] = node['ec2']['placement_availability_zone']
        node_hash['node_wan_address'] = node['ec2']['public_ipv4'].to_s
      else
        # check for other cloud providers
        node_hash['node_region'] = nil
      end

      node_hash[cluster_attribute] = node[cluster_attribute] if cluster_attribute

      if application_attribute
        if node[application_attribute].is_a?(String)
          node_hash[application_attribute] = node[application_attribute]
        elsif node[application_attribute].is_a?(Array)
          node_hash[application_attribute] = node[application_attribute].to_a.flatten
        end
      end

      node_hash
    end

    def validate_node(node_hash)
      fail ArgumentError, "#{node_hash['name']} missing 'hostname'" unless variable_check(node_hash['hostname'])
      fail ArgumentError, "#{node_hash['name']} missing 'fqdn'" unless variable_check(node_hash['fqdn'])
      fail ArgumentError, "#{node_hash['name']} missing 'ipaddress'" unless variable_check(node_hash['ipaddress'])
      fail ArgumentError, "#{node_hash['name']} missing '#{cluster_attribute}'" unless variable_check(node_hash[cluster_attribute]) if cluster_attribute
      fail ArgumentError, "#{node_hash['name']} missing '#{application_attribute}'" unless variable_check(node_hash[application_attribute]) if application_attribute
    end
  end
end
