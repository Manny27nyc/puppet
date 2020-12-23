class openstack::barbican::service::stein(
    String $db_user,
    String $db_pass,
    String $db_name,
    Stdlib::Fqdn $db_host,
    String $crypto_kek,
    String $ldap_user_pass,
    String $keystone_admin_uri,
    String $keystone_public_uri,
    Stdlib::Port $bind_port,
) {
    require "openstack::serverpackages::stein::${::lsbdistcodename}"

    package { 'barbican-api':
        ensure => 'present',
    }

    file {
        '/etc/barbican/barbican.conf':
            content   => template('openstack/stein/barbican/barbican.conf.erb'),
            owner     => 'barbican',
            group     => 'barbican',
            mode      => '0440',
            show_diff => false,
            notify    => Service['barbican-api'],
            require   => Package['barbican-api'];
        '/etc/barbican/policy.yaml':
            source  => 'puppet:///modules/openstack/stein/barbican/policy.yaml',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            notify  => Service['barbican-api'],
            require => Package['barbican-api'];
        '/etc/init.d/barbican-api':
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            content => template('openstack/stein/barbican/barbican-api.erb');
    }
}
