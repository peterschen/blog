---
title: Update DigitalOcean DNS entry on DHCP bind
author: Christoph Petersen
url: /update-digitalocean-dns-entry-on-dhcp-bind
date: 2019-07-26T09:02:19.000Z
tags: [networking, dns, digitalocean, script]
cover: 
  image: images/update-digitalocean-dns-entry-on-dhcp-bind.png
---

Many use services like DynDNS to make systems behind a dail-up or dynamic line accessible from the outside. But if your primary DNS is hosted somewhere else (e.g. Azure DNS or some other provider) and this provider offers APIs to interact with the domain records, it is pretty easy to write a script that will take of updating the IP when it changes.

In my scneario DNS is hosted with DigitalOcean. I want to make sure that everytime the IP on my home system changes this is reflected in the DNS records so that I can access it from the outside or to make some integrations work. I have a cable line and use IP pass-through so that the public IP I get assigned from my provider is not set on the cable modem but instead on the NIC of my gateway. **If your setup is different (e.g. using a DSL line or not having the option to employ IP pass-through) scroll to the end where I discuss alternative options.**

I'm running Debian with ISC dhcp on my server at home. This comes with a scripting interface that calls scripts when the dhcp process is started (dhclient-entry-hooks) and when it is completed (dhclient-exit-hooks). As we want to use the result of the dhcp protocol we use the exit-hooks infrastructure. For more details on this, refer to [the documentation](https://linux.die.net/man/8/dhclient-script).

I came up with the following script:

```sh
#!/usr/bin/env sh

PREFIX="dns-digitalocean"
DO_APITOKEN="<YOUR DO API TOKEN>"
DO_DNSZONE="<YOUR DNS ZONE>"
DO_DNSRECORD=<THE DNS RECORD>
IFACE="<THE INTERFACE (e.g. eth0, ...)"

# Only act on a specific interface
if [ "$IFACE" != "$interface" ]; then
        exit 0;
fi

# Only update when we got an IP
if [ "$reason" = BOUND ] || [ "$reason" = RENEW ] ||
[ "$reason" = REBIND ] || [ "$reason" = REBOOT ]; then
        IPNEW=$new_ip_address
        IPCUR= `cat /tmp/ip.cache`


        if [ "$IPNEW" != "$IPCUR" ]; then
                echo -n "${PREFIX}: Updating DigitalOcean DNS record: "
                curl --silent --show-error --output /dev/null -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer ${DO_APITOKEN}" -d '{"data":"'"${IPNEW}"'"}' "https://api.digitalocean.com/v2/domains/${DO_DNSZONE}/records/${DO_DNSRECORD}"

                if [ $? -eq 0 ]; then
                        echo "succeeded"
                else
                        echo "failed"
                fi

                echo ${IPNEW} > "/tmp/ip.cache"
        else
                echo "${PREFIX}: IP has not changed since last update"
        fi
fi

exit 0;
```

Put this script into `/etc/dhcp/dhclient-exit-hooks.d` . It will then be called every time the dhcp protocol was completed. The script checks whether `dhclient` was acting on the right interface and with the right intentions (e.g. we do not want to change anything if we release the IP address).

## Alternatives

If you are not as lucky as I am to use IP pass-through, there are other avenues where you could employ a modified version of the script. Instead of taking the IP as a parameter or environment variable you can use [ifconfig.co](https://ifconfig.co) to lookup your IP address and set it either on a schedule or by using the [if-up/if-down infrastructure ](https://www.debian.org/doc/manuals/debian-reference/ch05.en.html#_scripting_with_the_ifupdown_system)of your network stack.
