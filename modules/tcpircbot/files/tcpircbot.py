#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TCP -> IRC forwarder bot
Forward data from a TCP socket to one or more IRC channels,
and from specified files.

Usage: tcpircbot.py CONFIGFILE

CONFIGFILE should be a JSON file with the following structure:

  {
      "irc": {
          "channels": ["#wikimedia-operations", "#wikimedia-dev"],
          "network": ["irc.freenode.net", 7000, "serverpassword"],
          "nickname": "tcpircbot",
          "ssl": true
      },
      "tcp": {
          "max_clients": 5,
          "cidr": "::/0",
          "port": 9125
      },
      "infiles": []
  }

Requirements:
 * irc >=8.5.3
   <http://bitbucket.org/jaraco/irc>
   Debian package: 'python3-irc'
 * netaddr >=0.7.5
   <https://pypi.python.org/pypi/netaddr>
   Ubuntu package: 'python3-netaddr'
   (Not required for infile support)

The Puppet module bundled with this script will manage these
dependencies for you.

"""
import sys

import atexit
import codecs
import io
import json
import logging
import select
import socket
import ssl
import irc

import irc.bot as ircbot

BUFSIZE = 460  # Read from socket in IRC-message-sized chunks.

logging.basicConfig(level=logging.INFO, stream=sys.stderr,
                    format='%(asctime)-15s %(message)s')

files = []


class ForwarderBot(ircbot.SingleServerIRCBot):
    """Minimal IRC bot; joins channels."""

    def __init__(self, network, nickname, channels, **options):
        ircbot.SingleServerIRCBot.__init__(self, [network], nickname, nickname, **options)
        self.target_channels = channels
        for event in ['disconnect', 'join', 'part', 'welcome']:
            self.connection.add_global_handler(event, self.log_event)

    def on_privnotice(self, connection, event):
        logging.info('%s %s', event.source, event.arguments)

    def log_event(self, connection, event):
        if connection.real_nickname in [event.source, event.target]:
            logging.info('%(type)s [%(source)s -> %(target)s]'
                         % vars(event))

    def on_welcome(self, connection, event):
        for channel in self.target_channels:
            connection.join(channel)

        if 'infiles' in config:
            global files
            for infile in config['infiles']:
                f = open(infile, 'r')
                f.seek(0, 2)
                files.append(f)


if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help'):
    sys.exit(__doc__.lstrip())

with open(sys.argv[1]) as f:
    config = json.load(f)

# Create a bot and connect to IRC
# Mangle the config a bit for newer python-irc libraries
ipv6 = config['irc'].pop(u'ipv6', False)
if config['irc'].pop(u'ssl', False):
    factory = irc.connection.Factory(ipv6=ipv6, wrapper=ssl.wrap_socket)
else:
    factory = irc.connection.Factory(ipv6=ipv6)
config['irc']['connect_factory'] = factory
bot = ForwarderBot(**config['irc'])
bot._connect()

server = None
if 'tcp' in config:
    import netaddr

    # Create a TCP server socket
    server = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    server.setblocking(0)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    server.bind((config['tcp'].get('iface', ''), config['tcp']['port']))
    server.listen(config['tcp']['max_clients'])

    files.append(server)

    def close_sockets():
        for f in files:
            try:
                f.close()
            except socket.error:
                pass

    atexit.register(close_sockets)

    def is_ip_allowed(ip):
        """Check if we should accept a connection from remote IP `ip`. If
        the config specifies a CIDR, test against that; otherwise allow only
        private and loopback IPs. Multiple comma-separated CIDRs may be
        specified.
        """
        ip = netaddr.IPAddress(ip)
        if 'cidr' in config['tcp']:
            cidrs = config['tcp']['cidr']
            if not isinstance(cidrs, list):
                cidrs = cidrs.split(',')
            return any(ip in netaddr.IPNetwork(cidr) for cidr in cidrs)
        return ip.is_private() or ip.is_loopback()

while 1:
    readable, _, _ = select.select([bot.connection.socket] + files, [], [])
    for f in readable:
        if f is server:
            conn, addr = server.accept()
            if not is_ip_allowed(addr[0]):
                conn.close()
                continue
            conn.setblocking(0)
            logging.info('Connection from %s', addr)
            files.append(conn)
        elif f is bot.connection.socket:
            bot.connection.process_data()
        elif isinstance(f, io.IOBase):
            data = f.readline().rstrip()
            if data:
                logging.info('infile: %s', data)
                for channel in bot.target_channels:
                    bot.connection.privmsg(channel, data)
        else:
            data = f.recv(BUFSIZE)
            data = codecs.decode(data, 'utf8', 'replace').strip()
            if data:
                logging.info('TCP %s: "%s"', f.getpeername(), data)
                for channel in bot.target_channels:
                    bot.connection.privmsg(channel, data)
            else:
                f.close()
                files.remove(f)
