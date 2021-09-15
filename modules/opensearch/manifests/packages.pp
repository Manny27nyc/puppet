# == Class: opensearch::packages
#
# Provisions OpenSearch package and dependencies.
#
class opensearch::packages (
    String  $package_name,
    Boolean $send_logs_to_logstash,
) {
    include ::java::tools # lint:ignore:wmf_styleguide

    package { 'opensearch':
        ensure => present,
        name   => $package_name,
    }

    ### install and link additional log4j appender to send logs over GELF

    # we only require the packages, we do not remove them as there might be
    # other dependencies
    if $send_logs_to_logstash {
        ensure_packages('liblogstash-gelf-java')
        ensure_packages('libjson-simple-java')
    }

    # symlinks are removed if log shipping is disabled
    file { '/usr/share/opensearch/lib/logstash-gelf.jar':
        ensure => stdlib::ensure($send_logs_to_logstash, 'link'),
        target => '/usr/share/java/logstash-gelf.jar',
    }
    file { '/usr/share/opensearch/lib/json-simple.jar':
        ensure => stdlib::ensure($send_logs_to_logstash, 'link'),
        target => '/usr/share/java/json-simple.jar',
    }

}
