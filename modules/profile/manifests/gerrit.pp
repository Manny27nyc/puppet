# modules/profile/manifests/gerrit/server.pp
#
class profile::gerrit(
    Hash                              $ldap_config       = lookup('ldap', Hash, hash, {}),
    Stdlib::IP::Address::V4           $ipv4              = lookup('profile::gerrit::ipv4'),
    Optional[Stdlib::IP::Address::V6] $ipv6              = lookup('profile::gerrit::ipv6'),
    Stdlib::Fqdn                      $host              = lookup('profile::gerrit::host'),
    Boolean                           $backups_enabled   = lookup('profile::gerrit::backups_enabled'),
    String                            $backup_set        = lookup('profile::gerrit::backup_set'),
    Array[Stdlib::Fqdn]               $gerrit_servers    = lookup('profile::gerrit::servers'),
    String                            $config            = lookup('profile::gerrit::config'),
    Boolean                           $use_acmechief     = lookup('profile::gerrit::use_acmechief'),
    Boolean                           $is_replica        = lookup('profile::gerrit::is_replica'),
    Optional[Array[Stdlib::Fqdn]]     $replica_hosts     = lookup('profile::gerrit::replica_hosts'),
    Optional[String]                  $scap_user         = lookup('profile::gerrit::scap_user'),
    Optional[String]                  $scap_key_name     = lookup('profile::gerrit::scap_key_name'),
    Boolean                           $enable_monitoring = lookup('profile::gerrit::enable_monitoring'),
    Hash[String, Hash]                $replication       = lookup('profile::gerrit::replication'),
    String                            $ssh_host_key      = lookup('profile::gerrit::ssh_host_key'),
    Stdlib::Unixpath                  $git_dir           = lookup('profile::gerrit::git_dir'),
    Stdlib::Unixpath                  $java_home         = lookup('profile::gerrit::java_home'),
) {
    require ::profile::java

    interface::alias { 'gerrit server':
        ipv4 => $ipv4,
        ipv6 => $ipv6,
    }

    if !$is_replica and $enable_monitoring {
        monitoring::service { 'gerrit_ssh':
            description   => 'SSH access',
            check_command => "check_ssh_port_ip!29418!${ipv4}",
            contact_group => 'admins,gerrit',
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Gerrit',
        }
    }

    # ssh from users to gerrit
    ferm::service { 'gerrit_ssh_users':
        proto  => 'tcp',
        port   => '29418',
        drange => "(${ipv4} ${ipv6})",
    }

    # ssh between gerrit servers for cluster support
    $gerrit_servers_ferm=join($gerrit_servers, ' ')
    ferm::service { 'gerrit_ssh_cluster':
        port   => '22',
        proto  => 'tcp',
        srange => "(@resolve((${gerrit_servers_ferm})) @resolve((${gerrit_servers_ferm}), AAAA))",
    }

    ferm::service { 'gerrit_http':
        proto => 'tcp',
        port  => 'http',
    }

    ferm::service { 'gerrit_https':
        proto => 'tcp',
        port  => 'https',
    }

    if $backups_enabled and $backup_set != undef {
        backup::set { $backup_set:
            jobdefaults => "Hourly-${profile::backup::host::day}-${profile::backup::host::pool}"
        }
    }

    if $use_acmechief {
        class { 'sslcert::dhparam': }
        acme_chief::cert { 'gerrit':
            puppet_svc => 'apache2',
        }
    } else {
        ensure_packages('certbot')
        systemd::timer::job { 'certbot-renew':
            ensure      => present,
            user        => 'root',
            description => 'renew TLS certificate using certbot',
            command     => "/usr/bin/certbot -q renew --post-hook \"systemctl reload apache\"",
            interval    => {'start' => 'OnCalendar', 'interval' => '*-*-* 04:04:00'},
        }
    }

    class { 'gerrit':
        host              => $host,
        ipv4              => $ipv4,
        ipv6              => $ipv6,
        replica           => $is_replica,
        replica_hosts     => $replica_hosts,
        config            => $config,
        use_acmechief     => $use_acmechief,
        ldap_config       => $ldap_config,
        scap_user         => $scap_user,
        scap_key_name     => $scap_key_name,
        enable_monitoring => $enable_monitoring,
        replication       => $replication,
        ssh_host_key      => $ssh_host_key,
        git_dir           => $git_dir,
        java_home         => $java_home,
    }

    class { 'gerrit::replication_key':
        require => Class['gerrit'],
    }

    # Ship Gerrit built-in logs to ELK
    rsyslog::input::file { 'gerrit-json':
        path => '/var/log/gerrit/*_log.json',
    }

    # Apache reverse proxies to jetty
    rsyslog::input::file { 'gerrit-apache2-error':
        path => '/var/log/apache2/*error*.log',
    }
    rsyslog::input::file { 'gerrit-apache2-access':
        path => '/var/log/apache2/*access*.log',
    }
}
