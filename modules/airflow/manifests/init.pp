# == Class airflow
# Base class for declaring airflow::instances.
# Installs the WMF airflow .deb package as a conda environment into /usr/lib/airflow.
#
# Creates an 'airflow' control systemd service that all airflow::instance services
# declare themselves PartOf.  This can be used for easy managing of all local airflow services.
#
# Also installs a check_cmd used for NRPE checks when an airflow::instance
# has $monitoring_enabled => true.
#
class airflow {
    require_package('airflow')

    # Path to where airflow conda env is installed
    $airflow_prefix = '/usr/lib/airflow'

    # Generic nrpe check for running a command and checking its retval.
    # Used for custom Airflow CLI checks.
    file { '/usr/local/bin/check_cmd':
        ensure => 'present',
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/airflow/check_cmd.sh'
    }

    systemd::service { 'airflow':
        content => systemd_template('airflow'),
        restart => true,
    }

}
