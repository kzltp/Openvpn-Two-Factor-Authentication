#!/bin/bash

TEST_MODE=false # Test mode to use script from command line, being prompted for username and password
LDAP_SERVER='ldap.example.xom'
BASE_DN='dc=example,dc=com'
MEMBER_ATTR='member'
VPN_GROUP='openvpn_access'
HOMEDIR='/etc/openvpn'
CRED_FILE="$1" # Temporary file with credentials (username, password) is passed to script as first argument
MAX_LEN=256 # Maximum length in characters of username and password; longer strings will not be accepted
#/etc/openvpn/autheliadb/sync.sh
cn=''
pw=''
if $TEST_MODE
  then
  echo "Running in test mode"
  read -p "Username: " cn
  read -s -p "Password: " pw 
  echo
elif ! [ -r "$CRED_FILE" ]
  then
  echo "ERROR: Credentials file '${CRED_FILE}' does not exist or is not readable"
  exit 1
elif [ $(wc -l <"$CRED_FILE") -ne 2 ]
  then
  echo "ERROR: Credentials file '${CRED_FILE}' does not exactly how two lines of text"
  exit 2
else
  echo "Reading username and password from credentials file '${CRED_FILE}'"
  cn=$(head -n 1 "$CRED_FILE")
  pw=$(tail -n 1 "$CRED_FILE")
fi

if [ $(echo "$cn" | wc -m) -gt $MAX_LEN ]
  then
  echo "ERROR: Username is longer than $MAX_LEN characters - this is forbidden"
  exit 3
fi 

if [ $(echo "$pw" | wc -m) -gt $MAX_LEN ]
  then
  echo "ERROR: Password is longer than $MAX_LEN characters - this is forbidden"
  exit 4
fi
USER_F=$(echo $cn |  tr -dc '[:alnum:]\n\r')
echo $USER_F
uid=$(ldapsearch  -x -H ldap://${LDAP_SERVER} -b 'cn=users,cn=accounts,dc=i01,dc=paytr,dc=com' cn=${cn}  | grep '^uid:' | sort -r --ignore-case | cut -c6-999)


# ldapcompare argument format:
# ldapcompare [options] DN attr:value
#
# DN = distinguished name to perform comparison on
# attr:value = name of attribute to check : value to check for
#
# Options used:
# -x Use simple authentication instead of SASL.
# -D LDAP reprentation (DN = distinguished name) of the username used for the LDAP connection
# -w Password used for authentication upon connection to LDAP server
lpw="$(cut -d';' -f1 <<<"$pw")"
gpw="$(cut -d';' -f2- <<<"$pw")"


SECRET=$(/usr/bin/sqlite3 ${HOMEDIR}/db.sqlite3  'select * from totp_secrets;' | grep $cn | sed "s/"$cn\|"//g")

vrfy=$(oathtool -b --totp ${SECRET})


echo "Running command: ldapcompare -x -H ldap://${LDAP_SERVER} -D "uid=${uid},cn=users,${BASE_DN}" -w $SECRET$ "cn=${VPN_GROUP},cn=groups,${BASE_DN}" "${MEMBER_ATTR}:uid=${uid},cn=users,cn=accounts,dc=i01,dc=paytr,dc=com""
RESULT=$(ldapcompare -x -H ldap://${LDAP_SERVER} -D "uid=${uid},cn=users,${BASE_DN}" -w "${lpw}" "cn=${VPN_GROUP},cn=groups,${BASE_DN}" "${MEMBER_ATTR}:uid=${uid},cn=users,cn=accounts,dc=i01,dc=paytr,dc=com")
echo "LDAP compare result: $RESULT"

if [ "$RESULT" = 'TRUE' ]
  then
  echo "User '${uid}' is a member of group '${VPN_GROUP}'"
  if [ $gpw == $vrfy ]
	then
	echo "Google Authentication OK"
  else
	exit 5
  fi
else
  echo "ERROR: LDAP connection error or user '${uid}' not in group '${VPN_GROUP}'"
  exit 5 
fi
