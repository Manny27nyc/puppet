class role::wmcs::db::wikireplicas::analytics_multiinstance {

    system::role { $name:
        description => 'wikireplica database - analytics, multi-instance',
    }

    include ::profile::base::production
    include ::profile::wmcs::db::wikireplicas::mariadb_multiinstance
    include ::profile::base::firewall
    include ::profile::wmcs::db::wikireplicas::views
    include ::profile::mariadb::check_private_data
    include ::profile::wmcs::db::wikireplicas::kill_long_running_queries

}
