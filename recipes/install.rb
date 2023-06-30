#
# Cookbook Name:: td-agent
# Recipe:: install
#
#

Chef::Recipe.send(:include, TdAgent::Version)
Chef::Provider.send(:include, TdAgent::Version)

group node["td_agent"]["group"] do
  group_name node["td_agent"]["group"]
  gid node["td_agent"]["gid"] if node["td_agent"]["gid"]
  system true
  action     [:create]
end

user node["td_agent"]["user"] do
  comment  'td-agent'
  uid node["td_agent"]["uid"] if node["td_agent"]["uid"]
  system true
  group    node["td_agent"]["group"]
  home     '/var/run/td-agent'
  shell    '/bin/false'
  password nil
  manage_home true
  action   [:create, :manage]
end

directory '/var/run/td-agent/' do
  owner  node["td_agent"]["user"]
  group  node["td_agent"]["group"]
  mode   '0755'
  action :create
end

directory '/etc/td-agent/' do
  owner  node["td_agent"]["user"]
  group  node["td_agent"]["group"]
  mode   '0755'
  action :create
end

case node['platform_family']
when "debian"
  dist = node['lsb']['codename']
  platform = node["platform"]
  source =
    if major.nil? || major == '1'
      # version 1.x or no version
      if dist == 'precise'
        'http://packages.treasuredata.com/precise/'
      else
        'http://packages.treasuredata.com/debian/'
      end
    else
      # version 2.x or later
      "http://packages.treasuredata.com/#{major}/#{platform}/#{dist}/"
    end

  apt_repository "treasure-data" do
    uri source
    arch node["td_agent"]["apt_arch"]
    distribution dist
    components ["contrib"]
    key "https://packages.treasuredata.com/GPG-KEY-td-agent"
    action :add
    not_if { node['td_agent']['skip_repository'] }
  end
when "fedora"
  platform = node["platform"]
  source =
    if major.nil? || major == '1'
      "http://packages.treasuredata.com/redhat/$basearch"
    else
      # version 2.x or later
        "http://packages.treasuredata.com/#{major}/redhat/7/$basearch"
    end

  yum_repository "treasure-data" do
    description "TreasureData"
    url source
    gpgkey "https://packages.treasuredata.com/GPG-KEY-td-agent"
    action :add
    not_if { node['td_agent']['skip_repository'] }
  end
when "rhel", "amazon"
  # platform_family of Amazon Linux is judged as amazon in new version of ohai: https://github.com/chef/ohai/pull/971

  platform = node["platform"]
  source =
    case major
    when nil?,'1'
      "http://packages.treasuredata.com/redhat/$basearch"
    when '2'
      # https://docs.fluentd.org/v/0.12/articles/install-by-rpm#step-1-install-from-rpm-repository
      td_agent_version = node['td_agent']['version'].to_f
      if td_agent_version >= 2.5
        "http://packages.treasuredata.com/2.5/redhat/$releasever/$basearch"
      else
        "http://packages.treasuredata.com/2/redhat/$releasever/$basearch"
      end
    when '3'
      if platform == "amazon"
        platform_version = node["platform_version"].to_i
        amazon_version = if platform_version > 2000
                           1
                         else
                           platform_version
                         end
        "https://packages.treasuredata.com/#{major}/amazon/#{amazon_version}/$releasever/$basearch"
      else
        "http://packages.treasuredata.com/#{major}/redhat/$releasever/$basearch"
      end
    when '4'
      if platform == "amazon"
        platform_version = node["platform_version"].to_i
        amazon_version = if platform_version > 2000
                           raise "Unsupported version"
                         else
                           platform_version
                         end
        "http://packages.treasuredata.com/#{major}/amazon/#{amazon_version}/$basearch"
      else
        "http://packages.treasuredata.com/#{major}/redhat/$releasever/$basearch"
      end
    end
  yum_repository "treasure-data" do
    description "TreasureData"
    url source
    gpgkey "https://packages.treasuredata.com/GPG-KEY-td-agent"
    action :add
    not_if { node['td_agent']['skip_repository'] }
  end
end

directory "/etc/td-agent/conf.d" do
  owner node["td_agent"]["user"]
  group node["td_agent"]["group"]
  mode "0755"
  only_if { node["td_agent"]["includes"] }
end

package "td-agent" do
  retries 3
  retry_delay 10
  if node["td_agent"]["pinning_version"]
    action :install
    version node["td_agent"]["version"]
  else
    action :upgrade
  end
end
