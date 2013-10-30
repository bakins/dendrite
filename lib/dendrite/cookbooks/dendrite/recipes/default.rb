template Chef::Config[:nginx_config] do
  source "nginx.conf.erb"
  variables(
            nginx: node['nginx'],
            services: node['services']
            )
  notifies :reload, "service[nginx]"
end

service "nginx" do
  supports :restart => true, :reload => true, :status => true
  reload_command  Chef::Config[:nginx_reload]
  restart_command Chef::Config[:nginx_restart]
  start_command   Chef::Config[:nginx_start]
  stop_command    Chef::Config[:nginx_stop]
  status_command  Chef::Config[:nginx_status]
  action :start
end
