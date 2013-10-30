default['nginx']['worker_processes'] = node['cpu']['total']
default['nginx']['user'] = 'www-data'
default['nginx']['group'] = 'www-data'
default['nginx']['error_log'] = '/var/log/nginx/error.log';
default['nginx']['pid'] = '/var/run/nginx.pid';

default['nginx']['worker_rlimit_nofile'] = 262144;
default['nginx']['worker_rlimit_core'] = '512M';
default['nginx']['working_directory'] = '/tmp';
default['nginx']['timer_resolution'] = '10ms';

default['nginx']['worker_connections'] = 65536;
