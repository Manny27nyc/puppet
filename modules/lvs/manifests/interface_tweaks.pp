# This gathers up various ethernet settings for functional
#  fixups and optimizations specific to LVS in a single location

define lvs::interface_tweaks($bnx2x=false, $txqlen=false, $rss_pattern=false) {
    if $name != 'eth0' {
        interface::manual { $name: interface => $name }
    }

    # RSS/RPS/XPS-type perf stuff ( https://www.kernel.org/doc/Documentation/networking/scaling.txt )
    if $rss_pattern { interface::rps { $name: rss_pattern => $rss_pattern } }

    # Optional larger TX queue len for 10Gbps+
    if $txqlen { interface::txqueuelen { $name: len => $txqlen } }

    # bnx2x-specific stuff
    if $bnx2x {
        # Max for bnx2x/BCM57800, seems to eliminate the spurious rx drops under heavy traffic
        interface::ring { "${name} rxring": interface => $name, setting => 'rx', value => 4078 }
    }
}
