group { 'puppet': ensure => present }
Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }
File { owner => 0, group => 0, mode => 0644 }

class {'apt':
  always_apt_update => true,
}

Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

apt::source { 'mariadb':
    location   => 'http://mariadb.mirror.nucleus.be/repo/10.1/ubuntu',
    repos      => 'main',
    key        => 'cbcb082a1bb943db'
}

apt::key { '4F4EA0AAE5267A6C': }

apt::ppa { 'ppa:ondrej/php5':
  require => Apt::Key['4F4EA0AAE5267A6C']
}

apt::key { 'nginx':
  key     => 'FA4657A64602F602'
}

apt::ppa { 'ppa:adegtyarev/nginx-pagespeed':
  require => Apt::Key['nginx']
}

class { 'puphpet::dotfiles': }

package { [
    'build-essential',
    'vim',
    'curl',
    'git-core',
    'unzip'
  ]:
  ensure  => 'installed',
}

class { 'nginx':
    require => Apt::Ppa['ppa:adegtyarev/nginx-pagespeed']
}

file { "${nginx::config::nx_temp_dir}/nginx.d/police-001":
  ensure  => file,
  content => template('nginx/vhost/nooku.erb'),
  notify  => Class['nginx::service'],
}

class { 'php':
  version             => latest,
  package             => 'php5-fpm',
  service             => 'php5-fpm',
  service_autorestart => false,
  config_file         => '/etc/php5/fpm/php.ini',
  module_prefix       => '',
  require             => Apt::Ppa['ppa:ondrej/php5']
}

file { '/etc/php5/fpm/pool.d/www.conf':
  source  => 'puppet:///modules/php/www.conf',
  require => Class['php'],
  notify  => Service['php5-fpm']
}

php::module {
  [
    'php5-mysql',
    'php5-cli',
    'php5-curl',
    'php5-gd',
    'php5-intl',
    'php5-mcrypt',
    'php-apc',
  ]:
  service => 'php5-fpm',
}

service { 'php5-fpm':
  ensure     => running,
  enable     => true,
  hasrestart => true,
  hasstatus  => true,
  require    => Package['php5-fpm'],
}

class { 'php::devel':
  require => Class['php'],
}


class { 'xdebug':
  service => 'nginx',
}

class { 'composer':
  require => Package['php5-fpm', 'curl'],
}

puphpet::ini { 'xdebug':
  value   => [
    'xdebug.remote_autostart = 0',
    'xdebug.remote_connect_back = 1',
    'xdebug.remote_enable = 1',
    'xdebug.remote_handler = "dbgp"',
    'xdebug.remote_port = 9000',
    'xdebug.remote_host = "192.168.52.10"',
    'xdebug.show_local_vars = 1',
    'xdebug.profiler_enable = 0',
    'xdebug.profiler_enable_trigger = 1',
    'xdebug.max_nesting_level = 1000'
  ],
  ini     => '/etc/php5/fpm/conf.d/zzz_xdebug.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}

puphpet::ini { 'php':
  value   => [
    'date.timezone = "Europe/Brussels"'
  ],
  ini     => '/etc/php5/fpm/conf.d/zzz_php.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}

puphpet::ini { 'custom':
  value   => [
    'sendmail_path = /usr/bin/env catchmail -fnoreply@example.com',
    'display_errors = On',
    'error_reporting = E_ALL & ~E_STRICT',
    'upload_max_filesize = "256M"',
    'post_max_size = "256M"',
    'memory_limit = "128M"'
  ],
  ini     => '/etc/php5/fpm/conf.d/zzz_custom.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}

class { 'mysql::server':
  config_hash   => {
    'root_password' => 'root',
    'bind_address' => false,
  },
  package_name => 'mariadb-server',
  require      => Apt::Source['mariadb']
}

exec { 'grant-all-to-root':
  command     => "mysql --user='root' --password='root' --execute=\"GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;\"",
  require => Class['phpmyadmin']
}

class { 'phpmyadmin':
  require => [Class['mysql::server'], Class['mysql::config'], Class['php']],
}

nginx::resource::vhost { 'phpmyadmin.police.dev':
  ensure      => present,
  server_name => ['phpmyadmin.police.dev'],
  listen_port => 80,
  index_files => ['index.php'],
  www_root    => '/usr/share/phpmyadmin',
  try_files   => ['$uri', '$uri/', '/index.php?$args'],
  require     => Class['phpmyadmin'],
}

nginx::resource::location { "phpmyadmin-php":
  ensure              => 'present',
  vhost               => 'phpmyadmin.police.dev',
  location            => '~ \.php$',
  proxy               => undef,
  try_files           => ['$uri', '$uri/', '/index.php?$args'],
  www_root            => '/usr/share/phpmyadmin',
  location_cfg_append => {
    'fastcgi_split_path_info' => '^(.+\.php)(/.+)$',
    'fastcgi_param'           => 'PATH_INFO $fastcgi_path_info',
    'fastcgi_param '          => 'PATH_TRANSLATED $document_root$fastcgi_path_info',
    'fastcgi_param  '         => 'SCRIPT_FILENAME $document_root$fastcgi_script_name',
    'fastcgi_pass'            => '127.0.0.1:9000',
    'fastcgi_index'           => 'index.php',
    'include'                 => 'fastcgi_params'
  },
  notify              => Class['nginx::service'],
  require             => Nginx::Resource::Vhost['phpmyadmin.police.dev'],
}

exec { 'gem-i18n-legacy':
  command => 'sudo /opt/vagrant_ruby/bin/gem install i18n -v=0.6.5',
  unless  => 'test `/opt/vagrant_ruby/bin/gem list --local | grep -q 0.6.5; echo $?` -eq 0',
  path    => ['/usr/bin', '/bin'],
}

class { 'mailcatcher':
  require => Exec['gem-i18n-legacy']
}

class { 'less': }

class { 'uglifyjs': }

class { 'scripts': }

class { 'elasticsearch':
  java_install => true,
  manage_repo  => true,
  repo_version => '1.0',
  config  => {
      'node' => {
          'name'  => 'police001'
      },
      'index' => {
          'number_of_replicas' => '0',
          'number_of_shards'   => '5'
      }
  }
}

elasticsearch::plugin{'elasticsearch/marvel/latest':
  module_dir => 'marvel'
}
