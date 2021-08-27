# Openvpn Two Factor Authentication

## Requirement
You should install  ```oathtool```, ```ldap-utils``` ```sqlite3``` packages.
```bash

apt-get install oathtool ldap-utils sqlite3
```

## Installation

```bash
wget https://github.com/kzltp/Openvpn-Two-Factor-Authentication/archive/refs/heads/main.zip
unzip main.zip

```
Move all files to OpenVPN home directory.

```bash
mv Openvpn-Two-Factor-Authentication-main/* /etc/openvpn
```

Update ldap information in ```openvpn-two-factor-auth.sh``` 

Insert user google auth token to db.sqlite3

```bash
sqlite3 db.sqlite3
insert into totp_secrets values('$Uid$',$Token$);
```

Lines to add to OpenVPN configuration file.

```bash
script-security 2
tmp-dir "/dev/shm"
auth-user-pass-verify openvpn-ldap-auth.sh via-file
```
## Usage

When write password you should use below usage syntax

$LDAPPASS$;$GOOGLEAUTHCODE$
