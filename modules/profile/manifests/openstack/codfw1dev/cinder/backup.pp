class profile::openstack::codfw1dev::cinder::backup (
    String[1]               $version                 = lookup('profile::openstack::codfw1dev::version'),
    Array[Stdlib::Fqdn]     $openstack_controllers   = lookup('profile::openstack::codfw1dev::openstack_controllers'),
    Stdlib::Fqdn            $keystone_fqdn           = lookup('profile::openstack::codfw1dev::keystone_api_fqdn'),
    String[1]               $region                  = lookup('profile::openstack::codfw1dev::region'),
    String[1]               $ldap_user_pass          = lookup('profile::openstack::codfw1dev::ldap_user_pass'),
    Stdlib::Fqdn            $db_host                 = lookup('profile::openstack::codfw1dev::cinder::db_host'),
    Stdlib::Port            $api_bind_port           = lookup('profile::openstack::codfw1dev::cinder::api_bind_port'),
    String[1]               $ceph_pool               = lookup('profile::openstack::codfw1dev::cinder::ceph_pool'),
    String[1]               $libvirt_rbd_cinder_uuid = lookup('profile::ceph::client::rbd::libvirt_rbd_cinder_uuid'),
    Boolean                 $active                  = lookup('profile::openstack::codfw1dev::cinder::backup::active'),
    Stdlib::Unixpath        $backup_path             = lookup('profile::openstack::codfw1dev::cinder::backup::path'),
    Array[Stdlib::Unixpath] $lvm_pv_units            = lookup('profile::openstack::codfw1dev::cinder::backup::lvm::pv_units'),
    String[1]               $lvm_vg_name             = lookup('profile::openstack::codfw1dev::cinder::backup::lvm::vg_name'),
    String[1]               $lvm_lv_name             = lookup('profile::openstack::codfw1dev::cinder::backup::lvm::lv_name'),
    String[1]               $lvm_lv_size             = lookup('profile::openstack::codfw1dev::cinder::backup::lvm::lv_size'),
    String[1]               $lvm_lv_format           = lookup('profile::openstack::codfw1dev::cinder::backup::lvm::lv_format'),

) {
    class { 'profile::openstack::base::cinder::backup':
        version                 => $version,
        active                  => $active,
        openstack_controllers   => $openstack_controllers,
        keystone_fqdn           => $keystone_fqdn,
        region                  => $region,
        db_host                 => $db_host,
        ceph_pool               => $ceph_pool,
        api_bind_port           => $api_bind_port,
        ldap_user_pass          => $ldap_user_pass,
        libvirt_rbd_cinder_uuid => $libvirt_rbd_cinder_uuid,
        backup_path             => $backup_path,
        lvm_pv_units            => $lvm_pv_units,
        lvm_vg_name             => $lvm_vg_name,
        lvm_lv_name             => $lvm_lv_name,
        lvm_lv_size             => $lvm_lv_size,
        lvm_lv_format           => $lvm_lv_format,
    }
}
