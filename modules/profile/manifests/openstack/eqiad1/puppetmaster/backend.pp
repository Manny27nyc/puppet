class profile::openstack::eqiad1::puppetmaster::backend(
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::eqiad1::openstack_controllers'),
    Array[Stdlib::Fqdn] $designate_hosts = lookup('profile::openstack::eqiad1::designate_hosts'),
    $puppetmaster_ca = lookup('profile::openstack::eqiad1::puppetmaster::ca'),
    $puppetmasters = lookup('profile::openstack::eqiad1::puppetmaster::servers'),
    $encapi_db_host = lookup('profile::openstack::eqiad1::puppetmaster::encapi::db_host'),
    $encapi_db_name = lookup('profile::openstack::eqiad1::puppetmaster::encapi::db_name'),
    $encapi_db_user = lookup('profile::openstack::eqiad1::puppetmaster::encapi::db_user'),
    $encapi_db_pass = lookup('profile::openstack::eqiad1::puppetmaster::encapi::db_pass'),
    $labweb_hosts = lookup('profile::openstack::eqiad1::labweb_hosts'),
    ) {
    class {'::profile::openstack::base::puppetmaster::backend':
        openstack_controllers => $openstack_controllers,
        designate_hosts       => $designate_hosts,
        puppetmaster_ca       => $puppetmaster_ca,
        puppetmasters         => $puppetmasters,
        encapi_db_host        => $encapi_db_host,
        encapi_db_name        => $encapi_db_name,
        encapi_db_user        => $encapi_db_user,
        encapi_db_pass        => $encapi_db_pass,
        labweb_hosts          => $labweb_hosts,
    }
}
