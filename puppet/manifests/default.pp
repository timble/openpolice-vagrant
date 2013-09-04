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
  location => 'http://mariadb.cu.be//repo/5.5/ubuntu',
  key      => 'cbcb082a1bb943db',
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

class { 'nginx': }


nginx::resource::vhost { 'nooku.dev':
  ensure       => present,
  server_name  => [
    'nooku.dev'  ],
  listen_port  => 80,
  index_files  => [
    'index.html',
    'index.htm',
    'index.php'
  ],
  www_root     => '/var/www/',
  try_files    => ['$uri', '$uri/', '/index.php?$args'],
}

$path_translated = 'PATH_TRANSLATED $document_root$fastcgi_path_info'
$script_filename = 'SCRIPT_FILENAME $document_root$fastcgi_script_name'

nginx::resource::location { 'nooku.dev-php':
  ensure              => 'present',
  vhost               => 'nooku.dev',
  location            => '~ \.php$',
  proxy               => undef,
  try_files           => ['$uri', '$uri/', '/index.php?$args'],
  www_root            => '/var/www/',
  location_cfg_append => {
    'fastcgi_split_path_info' => '^(.+\.php)(/.+)$',
    'fastcgi_param'           => 'PATH_INFO $fastcgi_path_info',
    'fastcgi_param '          => $path_translated,
    'fastcgi_param  '         => $script_filename,
    'fastcgi_pass'            => '127.0.0.1:9000',
    'fastcgi_index'           => 'index.php',
    'include'                 => 'fastcgi_params'
  },
  notify              => Class['nginx::service'],
}

class { 'php':
  package             => 'php5-fpm',
  service             => 'php5-fpm',
  service_autorestart => false,
  config_file         => '/etc/php5/fpm/php.ini',
  module_prefix       => ''
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
    'xdebug.remote_host = "192.168.50.10"',
    'xdebug.show_local_vars = 1',
    'xdebug.profiler_enable = 0',
    'xdebug.profiler_enable_trigger = 1',
    'xdebug.max_nesting_level = 1000'
  ],
  ini     => '/etc/php5/conf.d/zzz_xdebug.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}

puphpet::ini { 'php':
  value   => [
    'date.timezone = "Europe/Brussels"'
  ],
  ini     => '/etc/php5/conf.d/zzz_php.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}

puphpet::ini { 'custom':
  value   => [
    'sendmail_path = /usr/bin/env catchmail -fnoreply@example.com',
    'display_errors = On',
    'error_reporting = -1',
    'upload_max_filesize = "256M"',
    'post_max_size = "256M"',
    'memory_limit = "128M"'
  ],
  ini     => '/etc/php5/conf.d/zzz_custom.ini',
  notify  => Service['php5-fpm'],
  require => Class['php'],
}


class { 'mysql::server':
  config_hash   => {
    'root_password' => 'root',
    'bind_address' => false,
  },
  package_name => 'mariadb-server'
}

exec { 'grant-all-to-root':
  command     => "mysql --user='root' --password='root' --execute=\"GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;\"",
  require => Class['phpmyadmin']
}
#mysql::db { '*':
 # grant    => [
 #   'ALL'
  # ],
  #user     => 'root',
  #password => 'root',
#host     => 'localhost',
  #sql      => '/var/www/replace_this.sql',
# charset  => 'utf8',
# require  => Class['mysql::server'],
#}

class { 'phpmyadmin':
  require => [Class['mysql::server'], Class['mysql::config'], Class['php']],
}

nginx::resource::vhost { 'phpmyadmin.nooku.dev':
  ensure      => present,
  server_name => ['phpmyadmin.nooku.dev'],
  listen_port => 80,
  index_files => ['index.php'],
  www_root    => '/usr/share/phpmyadmin',
  try_files   => ['$uri', '$uri/', '/index.php?$args'],
  require     => Class['phpmyadmin'],
}

nginx::resource::location { "phpmyadmin-php":
  ensure              => 'present',
  vhost               => 'phpmyadmin.nooku.dev',
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
  require             => Nginx::Resource::Vhost['phpmyadmin.nooku.dev'],
}

class { 'mailcatcher': }

class { 'less': }

class { 'uglifyjs': }