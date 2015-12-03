# role/eventlogging.pp
#
# These role classes configure various eventlogging services.
# The setup is described in detail on
# <https://wikitech.wikimedia.org/wiki/EventLogging>. End-user
# documentation is available in the form of a guide, located at
# <https://www.mediawiki.org/wiki/Extension:EventLogging/Guide>.
#
# There exist two APIs for generating events: efLogServerSideEvent() in
# PHP and mw.eventLog.logEvent() in JavaScript. Events generated in PHP
# are sent by the app servers directly to eventlog* servers on UDP port 8421.
# JavaScript-generated events are URL-encoded and sent to our servers by
# means of an HTTP/S request to bits, which a varnishkafka instance
# forwards to Kafka.  These event streams are parsed,
# validated, and multiplexed into an output streams in Kafka.


# == Class role::eventlogging
# Parent class for eventlogging service role classes.
# This just installs eventlogging and sets up some configuration variables.
#
class role::eventlogging {
    system::role { 'role::eventlogging':
        description => 'EventLogging',
    }

    # Infer Kafka cluster configuration from this class
    class { 'role::analytics::kafka::config': }

    # Event data flows through several processes.
    # By default, all processing is performed
    # on one node, but the work could be easily distributed across
    # multiple hosts.
    $eventlogging_host   = hiera('eventlogging_host', $::ipaddress)

    # Define statsd host url
    # for beta cluster, set in https://wikitech.wikimedia.org/wiki/Hiera:Deployment-prep
    $statsd_host         = hiera('eventlogging_statsd_host',      'statsd.eqiad.wmnet')

    $kafka_brokers_array = $role::analytics::kafka::config::brokers_array
    $kafka_zookeeper_url = $role::analytics::kafka::config::zookeeper_url

    # By default, the EL Kafka writer writes events to
    # schema based topic names like eventlogging_SCHEMA,
    # with each message keyed by SCHEMA_REVISION.
    # If you want to write to a different topic, append topic=<TOPIC>
    # to your query params.
    $kafka_base_uri    = inline_template('kafka:///<%= @kafka_brokers_array.join(":9092,") + ":9092" %>')

    # Read in server side and client side raw events from
    # Kafka, process them, and send events to schema
    # based topics in Kafka.

    # NOTE:
    # eventlogging in beta labs is running the service 'EventBus' branch, which
    # has changed the way topics are interpolated.  This conditional will
    # be removed when we deploy this to prod as well.
    if $::realm == 'labs' {
        $kafka_schema_uri  = "${kafka_base_uri}?topic=eventlogging_{schema}"
    }
    else {
        $kafka_schema_uri  = "${kafka_base_uri}?topic=eventlogging_%(schema)s"
    }

    # The downstream eventlogging MySQL consumer expects schemas to be
    # all mixed up in a single stream.  We send processed events to a
    # 'mixed' kafka topic in order to keep supporting it for now.
    # We blacklist certain high volume schemas from going into this topic.
    $mixed_schema_blacklist = hiera('eventlogging_valid_mixed_schema_blacklist', undef)
    $kafka_mixed_uri = $mixed_schema_blacklist ? {
        undef   => "${kafka_base_uri}?topic=eventlogging-valid-mixed",
        default => "${kafka_base_uri}?topic=eventlogging-valid-mixed&blacklist=${mixed_schema_blacklist}"
    }

    $kafka_server_side_raw_uri = "${kafka_base_uri}?topic=eventlogging-server-side"
    $kafka_client_side_raw_uri = "${kafka_base_uri}?topic=eventlogging-client-side"


    class { '::eventlogging': }

    # This check was written for eventlog1001, so only include it there.,
    if $::hostname == 'eventlog1001' {

        # Alert when / gets low. (eventlog1001 has a 9.1G /)
        nrpe::monitor_service { 'eventlogging_root_disk_space':
            description   => 'Eventlogging / disk space',
            nrpe_command  => '/usr/lib/nagios/plugins/check_disk -w 1024M -c 512M -p /',
            contact_group => 'analytics',
        }

        # Alert when /srv gets low. (eventlog1001 has a 456G /srv)
        # Currently, /srv/log/eventlogging grows at about 500kB / s.
        # Which is almost 2G / hour.  100G gives us about 2 days to respond,
        # 50G gives us about 1 day.  Logrotate should keep enough disk space free.
        nrpe::monitor_service { 'eventlogging_srv_disk_space':
            description   => 'Eventlogging /srv disk space',
            nrpe_command  => '/usr/lib/nagios/plugins/check_disk -w 100000M -c 50000M -p /srv',
            contact_group => 'analytics',
        }
    }

    # make sure any defined eventlogging services are running
    class { '::eventlogging::monitoring::jobs': }
}



#
# ==== Data flow classes ====
#


# == Class role::eventlogging::forwarder
# Responsible for forwarding incoming raw events from UDP
# into the eventlogging system.
#
class role::eventlogging::forwarder inherits role::eventlogging {
    # Server-side events are generated by MediaWiki and sent to eventlog*
    # on UDP port 8421, using wfErrorLog('...', 'udp://...'). eventlog*
    # is specified as the destination in $wgEventLoggingFile, declared
    # in wmf-config/CommonSettings.php.

    eventlogging::service::forwarder { 'server-side-raw':
        input   => 'udp://0.0.0.0:8421',
        # Don't use async producer for low volume server side forwarder.
        outputs => [
            "${kafka_server_side_raw_uri}&async=False",
        ],
        count   => true,
    }

    # This forwards the kafka eventlogging-valid-mixed topic to
    # ZMQ port 8600 for backwards compatibility.
    eventlogging::service::forwarder { 'legacy-zmq':
        input  => "${kafka_mixed_uri}&zookeeper_connect=${kafka_zookeeper_url}&auto_commit_enable=False&auto_offset_reset=-1",
        outputs => ["tcp://${eventlogging_host}:8600"],
    }
}


# == Class role::eventlogging::processor
# Reads raw events, parses and validates them, and then sends
# them along for further consumption.
#
class role::eventlogging::processor inherits role::eventlogging {
    $kafka_consumer_args  = hiera(
        'eventlogging_processor_kafka_consumer_args',
        'auto_commit_enable=True&auto_commit_interval_ms=10000&auto_offset_reset=-1'
    )
    $kafka_consumer_group = hiera(
        'eventlogging_processor_kafka_consumer_group',
        'eventlogging-00'
    )

    # Get etcd_hosts out of hiera and prepend them each with the
    # etcd client port, and join them into a string.
    $etcd_hosts = join(suffix(hiera('etcd_hosts'), ':2379'), ',')

    $etcd_uri  = "https://${etcd_hosts}"

    eventlogging::service::processor { 'server-side-0':
        format         => '%{seqId}d EventLogging %j',
        sid            => $kafka_consumer_group,
        etcd_uri       => $etcd_uri,
        input          => "${kafka_server_side_raw_uri}&zookeeper_connect=${kafka_zookeeper_url}&${kafka_consumer_args}",
        outputs        => [
            # Write valid events to schema based topics, and
            # also to the eventlogging-valid-mixed topic.
            $kafka_schema_uri,
            $kafka_mixed_uri,
        ],
        # Invalid events to to eventlogging_EventError topic
        output_invalid => true,
    }

    # Run N parallel client side processors.
    # These will auto balance amongst themselves.
    $client_side_processors = hiera(
        'eventlogging_client_side_processors',
        ['client-side-0']
    )
    eventlogging::service::processor { $client_side_processors:
        format         => '%q %{recvFrom}s %{seqId}d %t %h %{userAgent}i',
        input          => "${kafka_client_side_raw_uri}&zookeeper_connect=${kafka_zookeeper_url}&${kafka_consumer_args}",
        etcd_uri       => $etcd_uri,
        sid            => $kafka_consumer_group,
        outputs        => [
            $kafka_schema_uri,
            $kafka_mixed_uri,
        ],
        output_invalid => true,
    }
}


# == Class role::eventlogging::consumer::mysql
# Consumes the stream of events and writes them to MySQL
#
class role::eventlogging::consumer::mysql inherits role::eventlogging {
    ## MySQL / MariaDB

    # Log strictly valid events to the 'log' database on m4-master.

    $kafka_consumer_args  = hiera(
        'eventlogging_mysql_kafka_consumer_args',
        'auto_commit_enable=True&auto_commit_interval_ms=1000&auto_offset_reset=-1'
    )

    class { 'passwords::mysql::eventlogging': }    # T82265
    $mysql_user = $passwords::mysql::eventlogging::user
    $mysql_pass = $passwords::mysql::eventlogging::password
    $mysql_db = $::realm ? {
        production => 'm4-master.eqiad.wmnet/log',
        labs       => '127.0.0.1/log',
    }

    # Kafka consumer group for this consumer is mysql-m4-master
    eventlogging::service::consumer { 'mysql-m4-master':
        input  => "${kafka_mixed_uri}&zookeeper_connect=${kafka_zookeeper_url}&${kafka_consumer_args}",
        output => "mysql://${mysql_user}:${mysql_pass}@${mysql_db}?charset=utf8&statsd_host=${statsd_host}&replace=True",
        # Restrict permissions on this config file since it contains a password.
        owner  => 'root',
        group  => 'eventlogging',
        mode   => '0640',
    }
}


# == Class role::eventlogging::consumer::files
# Consumes streams of events and writes them to log files.
#
class role::eventlogging::consumer::files inherits role::eventlogging {
    # Log all raw log records and decoded events to flat files in
    # $log_dir as a medium of last resort. These files are rotated
    # and rsynced to stat1003 & stat1002 for backup.

    $log_dir = $::eventlogging::log_dir

    $kafka_consumer_args  = 'auto_commit_enable=True&auto_commit_interval_ms=10000&auto_offset_reset=-1'
    $kafka_consumer_group = hiera(
        'eventlogging_files_kafka_consumer_group',
        'eventlogging-files-00'
    )

    eventlogging::service::consumer {
        'server-side-events.log':
            input  => "${kafka_server_side_raw_uri}&zookeeper_connect=${kafka_zookeeper_url}&${kafka_consumer_args}&raw=True",
            output => "file://${log_dir}/server-side-events.log",
            sid    => $kafka_consumer_group;
        'client-side-events.log':
            input  => "${kafka_client_side_raw_uri}&zookeeper_connect=${kafka_zookeeper_url}&${kafka_consumer_args}&raw=True",
            output => "file://${log_dir}/client-side-events.log",
            sid    => $kafka_consumer_group;
        'all-events.log':
            input  =>  "${kafka_mixed_uri}&zookeeper_connect=${kafka_zookeeper_url}&${kafka_consumer_args}",
            output => "file://${log_dir}/all-events.log",
            sid    => $kafka_consumer_group;
    }

    $backup_destinations = $::realm ? {
        production => [  'stat1002.eqiad.wmnet', 'stat1003.eqiad.wmnet' ],
        labs       => false,
    }

    if ( $backup_destinations ) {
        class { 'rsync::server': }

        rsync::server::module { 'eventlogging':
            path        => $log_dir,
            read_only   => 'yes',
            list        => 'yes',
            require     => File[$log_dir],
            hosts_allow => $backup_destinations,
        }
    }
}
