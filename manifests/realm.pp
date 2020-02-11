# realm.pp
# Collection of global definitions used across sites, within one realm.
#

# Determine the site the server is in

$site = $facts['ipaddress'] ? {
    /^208\.80\.15[23]\./                                      => 'codfw',
    /^208\.80\.15[45]\./                                      => 'eqiad',
    /^10\.6[48]\./                                            => 'eqiad',
    /^10\.19[26]\./                                           => 'codfw',
    /^91\.198\.174\./                                         => 'esams',
    /^198\.35\.26\./                                          => 'ulsfo',
    /^10\.128\./                                              => 'ulsfo',
    /^10\.20\.0\./                                            => 'esams',
    /^103\.102\.166\./                                        => 'eqsin',
    /^10\.132\./                                              => 'eqsin',
    /^172\.16\.([0-9]|[1-9][0-9]|1([0-1][0-9]|2[0-7]))\./     => 'eqiad',
    /^172\.16\.(1(2[8-9]|[3-9][0-9])|2([0-4][0-9]|5[0-5]))\./ => 'codfw',
    default                                                   => '(undefined)'
}

# All WMCS hosts reside in one of the following domains
# - *.wmflabs
# - *.wikimedia.cloud
$wmcs_domains = ['.wmflabs', '.wikimedia.cloud']
if $wmcs_domains.any |$domain| { $trusted['certname'] =~ "${domain}$" } {
    $realm = 'labs'
    # Pull the project name from the certname. CloudVPS VM certs can be:
    #  * <hostname>.<projname>.<site>.wmflabs
    #  * <hostname>.<projname>.<deployment>.wikimedia.cloud
    #
    # See following page for additional context:
    # https://wikitech.wikimedia.org/wiki/Wikimedia_Cloud_Services_team/EnhancementProposals/DNS_domain_usage#Resolution
    $pieces = $trusted['certname'].split('.')

    # current / legacy FQDN.
    # This whole branch will go away eventually
    if $pieces[-1] == 'wmflabs' {
        if $pieces[2] != $site {
            fail("Incorrect site in certname. Should be ${site} but is ${pieces[2]}")
        }
        $labsproject = $pieces[1]
        $wmcs_deployment = $pieces[2] ? {
            'eqiad' => 'eqiad1',
            'codfw' => 'codfw1dev',
            default => fail("site (${pieces[2]}) is not supported")
        }
    } else {
        # new FQDN wikimedia.cloud
        $labsproject = $pieces[1] # $wmcs_project may make more sense
        $wmcs_deployment = $pieces[2]
    }

    # some final checks before we move on
    if $pieces[0] != $::hostname {
        fail("Cert hostname ${pieces[0]} does not match reported hostname ${::hostname}")
    }
    if $::labsproject == undef {
        fail('Failed to determine $::labsproject')
    }
    if $::wmcs_deployment == undef {
        fail('Failed to determine $::wmcs_deployment')
    }
    $projectgroup = "project-${labsproject}"
    $dnsconfig = lookup('labsdnsconfig',Hash, 'hash', {})
    $nameservers = [
        ipresolve($dnsconfig['recursor'], 4),
        ipresolve($dnsconfig['recursor_secondary'], 4)
    ]
} else {
    $realm = 'production'
    $nameservers = [ '10.3.0.1' ] # anycast
}

# This is used to define the fallback site and is to be used by applications that
# are capable of automatically detecting a failed service and falling back to
# another one. Only the 2 sites that make sense to really be here are added for
# now
$other_site = $site ? {
    'codfw' => 'eqiad',
    'eqiad' => 'codfw',
    default => '(undefined)'
}

$app_routes = hiera('discovery::app_routes')

$aqs_site = $app_routes['aqs']

$network_zone = $facts['ipaddress'] ? {
    /^10./  => 'internal',
    default => 'public'
}

# Hiera->Global to configure various classes for NUMA-aware networking
# 2 possible values:
# --
# off: no NUMA awareness
# on:  try confine network stuff to the NUMA node of the adapter
# --
# If facter detects no true NUMA (single-node), the hiera-configured setting
# will be forced to "off" here in the global
if size($facts['numa']['nodes']) > 1 {
    if $::hostname =~ /^cp/ {
        # on cache hosts, set numa_networking on by default
        $numa_networking = hiera('numa_networking', 'on')
    } else {
        $numa_networking = hiera('numa_networking', 'off')
    }
}
else {
    $numa_networking = 'off'
}

# TODO: create hash of all LVS service IPs

# Set some basic variables

# Temporary: puppetdb switch
# Note: $settings::storeconfigs_backend is a ruby symbol, thus it
# would never match in the equality below. So cast the variable to string. See
# https://tickets.puppetlabs.com/browse/PUP-6682
# lint:ignore:only_variable_string lint:ignore:quoted_booleans
$use_puppetdb = ("${settings::storeconfigs}" == 'true' and "${settings::storeconfigs_backend}" == 'puppetdb')
# lint:endignore

# TODO: SMTP settings

# TODO: NTP settings

# TODO: Better nesting of settings inside classes

## puppet-accessible list of private wikis
## please keep alphabetized
$private_wikis = [
    'advisorswiki',
    'arbcom_cswiki',
    'arbcom_dewiki',
    'arbcom_enwiki',
    'arbcom_fiwiki',
    'arbcom_nlwiki',
    'auditcomwiki',
    'boardgovcomwiki',
    'boardwiki',
    'chairwiki',
    'chapcomwiki',
    'checkuserwiki',
    'collabwiki',
    'ecwikimedia',
    'electcomwiki',
    'execwiki',
    'fdcwiki',
    'grantswiki',
    'id_internalwikimedia',
    'iegcomwiki',
    'ilwikimedia',
    'internalwiki',
    'legalteamwiki',
    'movementroleswiki',
    'noboard_chapterswikimedia',
    'officewiki',
    'ombudsmenwiki',
    'otrs_wikiwiki',
    'projectcomwiki',
    'searchcomwiki',
    'spcomwiki',
    'stewardwiki',
    'techconductwiki',
    'transitionteamwiki',
    'wg_enwiki',
    'wikimaniateamwiki',
    'zerowiki' ]

$private_tables = [
    '__wmf_checksums',
    'accountaudit_login',
    'arbcom1_vote',
    'archive_old',
    'blob_orphans',
    'blob_tracking',
    'bot_passwords',
    'bv2009_edits',
    'categorylinks_old',
    'click_tracking',
    'cu_changes',
    'cu_log',
    'cur',
    'echo_email_batch',
    'echo_event',
    'echo_target_page',
    'echo_unread_wikis',
    'echo_notification',
    'edit_page_tracking',
    'email_capture',
    'exarchive',
    'exrevision',
    'globalnames',
    'hidden',
    'image_old',
    'job',
    'linkscc',
    'localnames',
    'log_search',
    'logging_old',
    'long_run_profiling',
    'migrateuser_medium',
    'moodbar_feedback',
    'moodbar_feedback_response',
    'msg_resource',
    'oathauth_users',
    'oauth_accepted_consumer',
    'oauth2_access_tokens',
    'oauth_registered_consumer',
    'objectcache',
    'old_growth',
    'oldimage_old',
    'optin_survey',
    'prefstats',
    'prefswitch_survey',
    'profiling',
    'querycache',
    'querycache_info',
    'querycache_old',
    'querycachetwo',
    'reading_list',
    'reading_list_entry',
    'securepoll_cookie_match',
    'securepoll_elections',
    'securepoll_entity',
    'securepoll_lists',
    'securepoll_msgs',
    'securepoll_options',
    'securepoll_properties',
    'securepoll_questions',
    'securepoll_strike',
    'securepoll_voters',
    'securepoll_votes',
    'spoofuser',
    'text',
    'titlekey',
    'transcache',
    'uploadstash',
    'urlshortcodes', # This table could be public if needed # T219777#5073729
    'user_newtalk',
    'vote_log',
    'watchlist',
    'watchlist_expiry',
    'wikimedia_editor_tasks_counts',
    'wikimedia_editor_tasks_keys',
    'wikimedia_editor_tasks_targets_passed' ]

# Route list for mail coming from MediaWiki mailer
$wikimail_smarthost = hiera('wikimail_smarthost')

# Generic, default servers (order matters!)
$mail_smarthost = hiera('mail_smarthost')

$acmechief_host = hiera('acmechief_host')

$ntp_peers = hiera('ntp_peers')
