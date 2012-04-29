# Module: ipsec
#
# Maintains ipsec secured connections 
# see http://reductivelabs.com/trac/puppet/wiki/ExportedResources


# Class: ipsec::base
#
# Sets up, configures and starts IPSec on the node
class ipsec::base {
  if $operatingsystem == 'Debian' {
    package { 'racoon':
      ensure => installed,
    } 
  }

  package { "ipsec-tools":
    ensure => present,
  }
  
  File {
    ensure  => present,
    owner   => "root",
    group   => "root",
    mode    => "644",
    require => Package["ipsec-tools"],
  }

  file { "setkey.conf":
    name    => "/etc/racoon/setkey.conf",
    replace => "false",
    content => template("ipsec/setkey.conf.erb")
  }

  file { "racoon.conf":
    name    => "/etc/racoon/racoon.conf",
    content => template("ipsec/racoon.conf.erb")
  }

  file { 'racoon-ssl-dir':
    name   => '/etc/racoon/ssl',
    ensure => directory,
  }

  file { 'racoon-ssl-certificate':
    name   => "/etc/racoon/ssl/${fqdn}.cert",
    ensure => link,
    target => "/var/lib/puppet/ssl/certs/${fqdn}.pem",
  }

  file { 'racoon-ssl-key':
    name   => "/etc/racoon/ssl/${fqdn}.key",
    ensure => link,
    target => "/var/lib/puppet/ssl/private_keys/${fqdn}.pem",
  }

  exec { 'hash-puppet-ca':
    command => 'ln -s /var/lib/puppet/ssl/certs/ca.pem /etc/racoon/ssl/`openssl x509 -hash -noout -in /var/lib/puppet/ssl/certs/ca.pem`.0',
    unless  => 'test -L /etc/racoon/ssl/`openssl x509 -hash -noout -in /var/lib/puppet/ssl/certs/ca.pem`.0',
  }

  Ip_connection <<| sourceip == "$ipaddress" |>>  # we can only use one filter expression, 'and' or 'or' are not supported (yet (version 25.1)).

  service { "racoon":
    ensure  => running,
    require => [Package["ipsec-tools"], File["setkey.conf", "racoon.conf", "racoon-ssl-dir", "racoon-ssl-certificate", "racoon-ssl-key"], Exec['hash-puppet-ca']],
    stop    => "export SETKEY_FLUSH_OPTIONS=-FP && /etc/init.d/racoon stop"
  }
}

# 'present' =(present|absent)
# 'type' is e.g. 'syslog' or 'dns'
# 'port' can be 'any' for every port
define ipsec::ipconnection ( $present, $fqdn, $sourceip, $destip, $type, $port ) { 
  # client out connection
  @@ip_connection { "${sourceip}_${type}_out":
    ensure => "$present",
    alias => "${fqdn}_${type}_out",
    servicetype => "${type}",
    sourceip => "$sourceip",
    destip => "$destip",
    port => "$port",
    require     => [Package["ipsec-tools"], File["setkey.conf"], Service["racoon"]],
  }

  # client in connection
  @@ip_connection { "${sourceip}_${type}_in":
    ensure => "$present",
    alias => "${fqdn}_${type}_in",
    servicetype => "${type}",
    sourceip => "$destip",
    destip => "$sourceip",
    port => "$port",
    require     => [Package["ipsec-tools"], File["setkey.conf"], Service["racoon"]],
  }
}

