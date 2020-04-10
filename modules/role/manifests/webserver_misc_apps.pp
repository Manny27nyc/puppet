# a webserver for misc. apps
# (as opposed to static websites using webserver_misc_static)
class role::webserver_misc_apps {

    system::role { 'webserver_misc_apps':
        description => 'WMF misc apps web server'
    }

    include ::profile::standard
    include ::profile::base::firewall
    include ::profile::misc_apps::httpd       # common webserver setup
    include ::profile::tlsproxy::envoy        # TLS termination

    include ::profile::wikimania_scholarships      # https://scholarships.wikimedia.org
    include ::profile::iegreview                   # https://iegreview.wikimedia.org
    include ::profile::racktables                  # https://racktables.wikimedia.org
    include ::profile::microsites::annualreport    # https://annual.wikimedia.org
    include ::profile::microsites::static_bugzilla # https://static-bugzilla.wikimedia.org
    include ::profile::microsites::static_rt       # https://static-rt.wikimedia.org
    include ::profile::microsites::transparency    # https://transparency.wikimedia.org
    include ::profile::microsites::research        # https://research.wikimedia.org (T183916)
    include ::profile::microsites::design          # https://design.wikimedia.org (T185282)
    include ::profile::microsites::sitemaps        # https://sitemaps.wikimedia.org
    include ::profile::microsites::bienvenida      # https://bienvenida.wikimedia.org (T207816)
    include ::profile::microsites::wikiworkshop    # https://wikiworkshop.org (T242374)
}
