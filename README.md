# exim-invaluement-updater
Download Invaluement SPBL, convert to Exim ACL files and update.

## The Basics

[Invaluement](https://www.invaluement.com/serviceproviderdnsbl/) is maintaining
two lists of bad actors at email service providers (at the time of writing only
SendGrid). This is the Invaluement SPBL.

There's a list of client IDs and a list of client domains. Client IDs can be
parsed out of envelope sender, and the client domains appear as the envelope
sender. Either way, you can use Invaluement's lists for SMTP-time ACLs.

This script checks for newer lists, downloads them and converts them to
Exim-format ACL files.

## Prerequisites

`bash` and `curl`.

## Configuration
As long as you are willing to accept default file locations and names then
there isn't anything to configure. See the top of `exim-invaluement-updater.sh`
for what little can be changed if needed.

You will also need to reference the ACL files this creates from your main Exim
configuration. Generate the ACL files first and then see the "Exim
Configuration" section below.

### Logging
By default the stderr log level is set to 2 (warnings and above) and the syslog
level is set to 3 (notices and above). As this script is typically run from
cron any output might be lost or end up as an email.

Set the environment variables `LOG_LEVEL` and/or `SYSLOG_LEVEL` to a numeric
value to use something other than defaults. These can be set to:

| Level | Meaning                |
| ----- | ---------------------- |
| 0     | Fatal issues only      |
| 1     | Errors or above        |
| 2     | Warnings or above      |
| 3     | Notices or above       |
| 4     | Informational or above |
| 5     | Debug or above         |

## Installation
1. Place `exim-invaluement-updater.sh` in `/usr/local/sbin/`.

2. Run `/usr/local/sbin/exim-invaluement-updater.sh` manually as root to make
   sure it works. By default this will create ACL files in
   `/var/lib/invaluement-spbl/`.

3. Place `etc/cron.d/exim-invaluement-updater` in `/etc/cron.d/` to make it run
   every day.

4. Edit your Exim configuration to reference the created ACL files (see below).

## Exim Configuration
Once you've verified that the two ACL files are being created correctly you
will need to reference them from your Exim configuration. Something like this
should suffice:

```
deny
  message = Sender envelope address $sender_address is listed by \
      Invaluement ID SPBL. If you think this is in error, please \
      contact postmaster@example.com
  senders = ${if exists{/var/lib/invaluement-spbl/spbl-ids}\
                 {/var/lib/invaluement-spbl/spbl-ids}\
                 {}}

deny
  message = Sender envelope address $sender_address is listed by \
      Invaluement Domain SPBL. If you think this is in error, \
      please contact postmaster@example.com
  senders = ${if exists{/var/lib/invaluement-spbl/spbl-domains}\
                 {/var/lib/invaluement-spbl/spbl-domains}\
                 {}}
```

Obviously change file name if you put them somewhere else.

Restart Exim and watch the logs to check everything is okay.

## Running as Non-root
The default setting for `data_dir` is `/var/lib/invaluement-spbl` and if this
directory doesn't exist the script will try to create it, which requires root
access. This is the only thing it does which requires root access, so if you'd
like to run it as an unpriveleged user — undoubtedly a good idea — all you need
to do is:

1. Make sure that `/var/lib/invaluement-spbl` (or whatever you set `data_dir`
   to) exists and is owned by the correct user.

2. Change the user in `/etc/cron.d/exim-invaluement-updater` from root to the
   correct user.

Note that your Exim process runs under its own user too. For example in Debian
it runs as `Debian-exim`. Your Exim user will require read access to
`/var/lib/invaluement-spbl` and the files inside it. It doesn't seem terrible
to leave the files world readable, but if you don't like that then you may need
to play with groups or filesystem ACLs.

## Related Projects
* [spamassassin-esp](https://github.com/bigio/spamassassin-esp) is a
  SpamAssassin plugin which uses a downloaded copy of the SPBL to match
  incoming mails and allow you to add your own scores. You'd need to manage the
  regular download of the SPBL yourself.
* [spamassassin-sendgrid](https://github.com/fmbla/spamassassin-sendgrid) is a
  SpamAssassin plugin which extracts the SendGrid client ID and allows it to
  be queried against a DNSBL, for those who have loaded Invaluement's lists
  into a DNS server.
* John Hardin [wrote a
  thing](http://www.impsec.org/~jhardin/antispam/make_sendgrid_rule.sh) that
  turns the lists into a SpamAssassin rule file for direct blocking.
