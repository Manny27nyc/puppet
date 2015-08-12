@monitoring::group { 'swift':
    description => 'swift servers',
}


class role::swift {
    class base {
        include standard
    }

    class eqiad_prod inherits role::swift::base {
        system::role { 'role::swift::eqiad-prod':
            description => 'Swift eqiad production cluster',
        }
        include passwords::swift::eqiad_prod
        class { '::swift::base':
            hash_path_suffix => '4f93c548a5903a13',
            cluster_name     => 'eqiad-prod',
        }
        class stats_reporter inherits role::swift::eqiad_prod {

            require_package('python-statsd')

            # one host per cluster should report global stats
            file { '/usr/local/bin/swift-ganglia-report-global-stats':
                ensure => absent,
            }
            # config file to hold the  password
            $password = $passwords::swift::eqiad_prod::rewrite_password
            file { '/etc/swift-ganglia-report-global-stats.conf':
                ensure  => absent,
            }
            cron { 'swift-ganglia-report-global-stats':
                ensure  => absent,
            }
            # report global stats to graphite
            file { '/usr/local/bin/swift-account-stats':
                ensure  => present,
                owner   => 'root',
                group   => 'root',
                mode    => '0555',
                source  => 'puppet:///files/swift/swift-account-stats',
                require => [Package['python-swiftclient'],
                            Package['python-statsd']
                        ],
            }
            file { '/etc/swift/account_mw_media.env':
                owner   => 'root',
                group   => 'root',
                mode    => '0440',
                content => "export ST_AUTH=http://ms-fe.eqiad.wmnet/auth/v1.0\nexport ST_USER=mw:media\nexport ST_KEY=${password}\n"
            }
            cron { 'swift-account-stats_mw_media':
                ensure  => present,
                command => ". /etc/swift/account_mw_media.env && /usr/local/bin/swift-account-stats --prefix swift.eqiad-prod.stats --statsd-host statsd.eqiad.wmnet 1>/dev/null",
                user    => 'root',
                hour    => '*',
                minute  => '*',
            }
            # swift-dispersion reporting
            file { '/usr/local/bin/swift-dispersion-stats':
                ensure  => present,
                owner   => 'root',
                group   => 'root',
                mode    => '0555',
                source  => 'puppet:///files/swift/swift-dispersion-stats',
                require => [Package['swift'],
                            Package['python-statsd']
                        ],
            }
            cron { 'swift-dispersion-stats':
                ensure  => present,
                command => "/usr/local/bin/swift-dispersion-stats --prefix swift.eqiad-prod.dispersion --statsd-host statsd.eqiad.wmnet >/dev/null 2>&1",
                user    => 'root',
                hour    => '*',
                minute  => '*/15',
            }
        }
        class proxy inherits role::swift::eqiad_prod {
            class { '::swift::proxy':
                statsd_host          => 'localhost',
                statsd_metric_prefix => "swift.eqiad-prod.${::hostname}",
                bind_port            => '80',
                proxy_address        => 'http://ms-fe.eqiad.wmnet',
                num_workers          => $::processorcount,
                memcached_servers    => ['ms-fe1001.eqiad.wmnet:11211',
                                        'ms-fe1002.eqiad.wmnet:11211',
                                        'ms-fe1003.eqiad.wmnet:11211',
                                        'ms-fe1004.eqiad.wmnet:11211'
                                        ],
                auth_backend         => 'tempauth',
                super_admin_key      => $passwords::swift::eqiad_prod::super_admin_key,
                rewrite_account      => 'AUTH_mw',
                rewrite_password     => $passwords::swift::eqiad_prod::rewrite_password,
                rewrite_thumb_server => 'rendering.svc.eqiad.wmnet',
                shard_container_list => 'wikipedia-commons-local-thumb,wikipedia-de-local-thumb,wikipedia-en-local-thumb,wikipedia-fi-local-thumb,wikipedia-fr-local-thumb,wikipedia-he-local-thumb,wikipedia-hu-local-thumb,wikipedia-id-local-thumb,wikipedia-it-local-thumb,wikipedia-ja-local-thumb,wikipedia-ro-local-thumb,wikipedia-ru-local-thumb,wikipedia-th-local-thumb,wikipedia-tr-local-thumb,wikipedia-uk-local-thumb,wikipedia-zh-local-thumb,wikipedia-commons-local-public,wikipedia-de-local-public,wikipedia-en-local-public,wikipedia-fi-local-public,wikipedia-fr-local-public,wikipedia-he-local-public,wikipedia-hu-local-public,wikipedia-id-local-public,wikipedia-it-local-public,wikipedia-ja-local-public,wikipedia-ro-local-public,wikipedia-ru-local-public,wikipedia-th-local-public,wikipedia-tr-local-public,wikipedia-uk-local-public,wikipedia-zh-local-public,wikipedia-commons-local-temp,wikipedia-de-local-temp,wikipedia-en-local-temp,wikipedia-fi-local-temp,wikipedia-fr-local-temp,wikipedia-he-local-temp,wikipedia-hu-local-temp,wikipedia-id-local-temp,wikipedia-it-local-temp,wikipedia-ja-local-temp,wikipedia-ro-local-temp,wikipedia-ru-local-temp,wikipedia-th-local-temp,wikipedia-tr-local-temp,wikipedia-uk-local-temp,wikipedia-zh-local-temp,wikipedia-commons-local-transcoded,wikipedia-de-local-transcoded,wikipedia-en-local-transcoded,wikipedia-fi-local-transcoded,wikipedia-fr-local-transcoded,wikipedia-he-local-transcoded,wikipedia-hu-local-transcoded,wikipedia-id-local-transcoded,wikipedia-it-local-transcoded,wikipedia-ja-local-transcoded,wikipedia-ro-local-transcoded,wikipedia-ru-local-transcoded,wikipedia-th-local-transcoded,wikipedia-tr-local-transcoded,wikipedia-uk-local-transcoded,wikipedia-zh-local-transcoded,global-data-math-render',
                backend_url_format   => 'sitelang',
                dispersion_password  => $passwords::swift::eqiad_prod::dispersion_password,
                search_password      => $passwords::swift::eqiad_prod::search_password,
            }
            class { '::swift::proxy::monitoring':
                host => 'ms-fe.eqiad.wmnet',
            }
            include ::swift_new::params
            include ::swift_new::container_sync

            include role::statsite
        }
        class storage inherits role::swift::eqiad_prod {
            include ::swift::storage
            include ::swift::storage::monitoring
            include ::swift_new::params
            include ::swift_new::container_sync

            include role::statsite
        }
    }
    class esams_prod inherits role::swift::base {
        system::role { 'role::swift::esams-prod':
            description => 'Swift esams production cluster',
        }
        include passwords::swift::esams_prod
        class { '::swift::base':
            hash_path_suffix => 'a0af6563d361f968',
            cluster_name     => 'esams-prod',
        }
        class ganglia_reporter inherits role::swift::esams_prod {
            # one host per cluster should report global stats
            file { '/usr/local/bin/swift-ganglia-report-global-stats':
                ensure => present,
                owner  => 'root',
                group  => 'root',
                mode   => '0555',
                source => 'puppet:///files/swift/swift-ganglia-report-global-stats',
            }
            # config file to hold the password
            $password = $passwords::swift::esams_prod::rewrite_password
            file { '/etc/swift-ganglia-report-global-stats.conf':
                owner   => 'root',
                group   => 'root',
                mode    => '0440',
                content => template('swift/swift-ganglia-report-global-stats.conf.erb'),
            }
            cron { 'swift-ganglia-report-global-stats':
                ensure  => present,
                command => "/usr/local/bin/swift-ganglia-report-global-stats -C /etc/swift-ganglia-report-global-stats.conf -u 'mw:media' -c esams-prod",
                user    => 'root',
            }
            # report global stats to graphite
            file { '/usr/local/bin/swift-account-stats':
                ensure  => present,
                owner   => 'root',
                group   => 'root',
                mode    => '0555',
                source  => 'puppet:///files/swift/swift-account-stats',
                require => [Package['python-swiftclient'],
                            Package['python-statsd']
                        ],
            }
            file { '/etc/swift/account_mw_media.env':
                owner   => 'root',
                group   => 'root',
                mode    => '0440',
                content => "export ST_AUTH=http://ms-fe.esams.wmnet/auth/v1.0\nexport ST_USER=mw:media\nexport ST_KEY=${password}\n"
            }
            cron { 'swift-account-stats_mw_media':
                ensure  => present,
                command => ". /etc/swift/account_mw_media.env && /usr/local/bin/swift-account-stats --prefix swift.esams-prod.stats --statsd-host statsd.eqiad.wmnet 1>/dev/null",
                user    => 'root',
                hour    => '*',
                minute  => '*',
            }
            # swift-dispersion reporting
            file { '/usr/local/bin/swift-dispersion-stats':
                ensure  => present,
                owner   => 'root',
                group   => 'root',
                mode    => '0555',
                source  => 'puppet:///files/swift/swift-dispersion-stats',
                require => [Package['swift'],
                            Package['python-statsd']
                        ],
            }
            cron { 'swift-dispersion-stats':
                ensure  => present,
                command => "/usr/local/bin/swift-dispersion-stats --prefix swift.esams-prod.dispersion --statsd-host statsd.eqiad.wmnet >/dev/null 2>&1",
                user    => 'root',
                hour    => '*',
                minute  => '*/15',
            }
        }
        class proxy inherits role::swift::esams_prod {
            class { '::swift::proxy':
                statsd_host          => 'localhost',
                statsd_metric_prefix => "swift.esams-prod.${::hostname}",
                bind_port            => '80',
                proxy_address        => 'http://ms-fe.esams.wmnet',
                num_workers          => $::processorcount,
                memcached_servers    => ['ms-fe3001.esams.wmnet:11211',
                                        'ms-fe3002.esams.wmnet:11211'
                                        ],
                auth_backend         => 'tempauth',
                super_admin_key      => $passwords::swift::esams_prod::super_admin_key,
                rewrite_account      => 'AUTH_mw',
                rewrite_password     => $passwords::swift::esams_prod::rewrite_password,
                rewrite_thumb_server => 'upload.wikimedia.org',
                shard_container_list => '',
                backend_url_format   => 'asis',
                dispersion_password  => $passwords::swift::esams_prod::dispersion_password,
                search_password      => $passwords::swift::esams_prod::search_password,
            }
            class { '::swift::proxy::monitoring':
                host => 'ms-fe.esams.wmnet',
            }

            include role::statsite
        }
        class storage inherits role::swift::esams_prod {
            include ::swift::storage
            include ::swift::storage::monitoring

            include role::statsite
        }
    }

}

#######
# NB. new swift module usage
# initially only codfw, to be followed by esams and eqiad

class role::swift::stats_reporter {
    include role::swift::base

    system::role { 'role::swift::stats_reporter':
        description => 'swift statistics reporter',
    }

    include ::swift_new::params
    include ::swift_new::stats::dispersion
    include ::swift_new::stats::accounts
}

class role::swift::proxy {
    include role::swift::base

    system::role { 'role::swift::proxy':
        description => 'swift frontend proxy',
    }

    include ::swift_new::params
    include ::swift_new
    include ::swift_new::ring
    include ::swift_new::container_sync

    class { '::swift_new::proxy':
        statsd_metric_prefix => "swift.${::swift_new::params::swift_cluster}.${::hostname}",
    }

    class { '::memcached':
        size => 128,
        port => 11211,
    }

    include role::statsite

    monitoring::service { 'swift-http-frontend':
        description   => 'Swift HTTP frontend',
        check_command => "check_http_url!${swift_check_http_host}!/monitoring/frontend",
    }
    monitoring::service { 'swift-http-backend':
        description   => 'Swift HTTP backend',
        check_command => "check_http_url!${swift_check_http_host}!/monitoring/backend",
    }
}


class role::swift::storage {
    include role::swift::base

    system::role { 'role::swift::storage':
        description => 'swift storage brick',
    }

    include ::swift_new::params
    include ::swift_new
    include ::swift_new::ring
    class { '::swift_new::storage':
        statsd_metric_prefix => "swift.${::swift_new::params::swift_cluster}.${::hostname}",
    }
    include ::swift_new::container_sync
    include ::swift_new::storage::monitoring

    include role::statsite

    $all_drives = hiera('swift_storage_drives')

    swift_new::init_device { $all_drives:
        partition_nr => '1',
    }

    # these are already partitioned and xfs formatted by the installer
    $aux_partitions = hiera('swift_aux_partitions')
    swift_new::label_filesystem { $aux_partitions: }
    swift_new::mount_filesystem { $aux_partitions: }
}
