#
# Cookbook Name:: nodes_db
# Recipe:: default
#
# Copyright 2015, Virender Khatri
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

fail "supported file types are 'yaml json all'" unless %w(all json yaml).include?(node['nodes_db']['file_type'])

directory node['nodes_db']['dir'] do
  owner node['nodes_db']['owner']
  group node['nodes_db']['group']
  mode 0755
end

node['nodes_db']['environments'].each do |env|
  case node['nodes_db']['file_type']
  when 'all'
    %w(json yaml).each do |file_type|
      r_content = RundeckNodes::Search.new(environment: env,
                                           cluster_attribute: node['nodes_db']['cluster_attribute'],
                                           application_attribute: node['nodes_db']['application_attribute'],
                                           search_pattern: node['nodes_db']['search_pattern'],
                                           ignore_node_error: node['nodes_db']['ignore_node_error'],
                                           file_type: file_type,
                                           username: node['nodes_db']['username']).environment_resources
      file ::File.join(node['nodes_db']['dir'], "#{env}.#{file_type}") do
        owner node['nodes_db']['owner']
        group node['nodes_db']['group']
        mode 0755
        content r_content
      end
    end
  else
    r_content = RundeckNodes::Search.new(environment: env,
                                         cluster_attribute: node['nodes_db']['cluster_attribute'],
                                         application_attribute: node['nodes_db']['application_attribute'],
                                         search_pattern: node['nodes_db']['search_pattern'],
                                         ignore_node_error: node['nodes_db']['ignore_node_error'],
                                         file_type: node['nodes_db']['file_type'],
                                         username: node['nodes_db']['username']).environment_resources
    file ::File.join(node['nodes_db']['dir'], "#{env}.#{node['nodes_db']['file_type']}") do
      owner node['nodes_db']['owner']
      group node['nodes_db']['group']
      mode 0755
      content r_content
    end
  end
end
