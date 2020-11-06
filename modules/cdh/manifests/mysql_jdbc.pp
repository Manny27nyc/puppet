# == define cdh::mysql_jdbc
#
# Helper to deploy Mysql/Mariadb jars and custom symlinks
# where needed.
#
define cdh::mysql_jdbc (
    String $link_path,
    Optional[Boolean] $use_mysql_jar = false,
) {
    if debian::codename::le('stretch') {
        $package_name = 'libmysql-java'
        $jar_path = $use_mysql_jar ? {
            true    => '/usr/share/java/mysql.jar',
            default => '/usr/share/java/mysql-connector-java.jar',
        }
    } else {
        $package_name = 'libmariadb-java'
        $jar_path = '/usr/share/java/mariadb-java-client-2.3.0.jar'
    }

    if (!defined(Package[$package_name])) {
        package { $package_name:
            ensure => 'installed',
        }
    }
    file { $link_path:
        ensure  => 'link',
        target  => $jar_path,
        require => Package[$package_name],
    }
}
