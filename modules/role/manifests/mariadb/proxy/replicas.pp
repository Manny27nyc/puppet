# db replicas load balancing with a proxy
class role::mariadb::proxy::replicas {
    include ::profile::base::production

    system::role { 'mariadb::proxy':
        description => 'DB Proxy with load balancing',
    }
    include ::profile::mariadb::proxy
    include ::profile::mariadb::proxy::multiinstance_replicas
    include profile::lvs::realserver
}
