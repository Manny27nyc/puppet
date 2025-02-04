# = Class: role::discovery::dashboards
#
# This class sets up R/Shiny-based Discovery Dashboards
# for tracking Search, Wikipedia.org portal, Wikidata
# Query Service, and Maps usage metrics and other KPIs.
#
class role::discovery::dashboards {
    # include ::profile::base::production
    # include ::profile::base::firewall
    include ::profile::discovery_dashboards::production

    system::role { 'role::discovery::dashboards':
        ensure      => 'present',
        description => 'Discovery Dashboards (Production)',
    }

}
