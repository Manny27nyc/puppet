# role classes for dataset servers

# common classes included by all dataset servers
class role::dataset::common {

    include standard
    include admins::roots

    include groups::wikidev
    include accounts::catrope

}

# a dumps primary server has dumps generated on this host; other directories
# of content may or may not be generated here (but should all be eventually)
# mirrors to the public should not be provided from here via rsync
class role::dataset::primary {
    $rsync = {
        'public' => true,
        'peers'  => true,
        'labs'   => true,
    }
    $grabs = {
#        'kiwix' => true,
    }
    $uploads = {
#        'pagecounts' => true,
#        'searchlogs' => true,
    }
    class { 'dataset':
        rsync        => $rsync,
        grabs        => $grabs,
        uploads      => $uploads,
    }
    include role::dataset::common
}

# a dumps secondary server may be a primary source of content for a small
# number of directories (but best is not at all)
# mirrors to the public should be provided from here via rsync
class role::dataset::secondary {
    $rsync = {
        'public' => true,
        'peers'  => true,
    }
    $uploads = {
        'pagecounts' => true,
        'searchlogs' => true,
    }
    $grabs = {
        'kiwix' => true,
    }
    class { 'dataset':
        rsync        => $rsync,
        grabs        => $grabs,
        uploads      => $uploads,
    }
    include role::dataset::common
}
