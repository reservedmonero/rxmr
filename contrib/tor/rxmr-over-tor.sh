#!/bin/bash

DIR=$(realpath $(dirname $0))

echo "Checking rxmrd..."
rxmrd=""
for dir in \
  . \
  "$DIR" \
  "$DIR/../.." \
  "$DIR/build/release/bin" \
  "$DIR/../../build/release/bin" \
  "$DIR/build/Linux/master/release/bin" \
  "$DIR/../../build/Linux/master/release/bin" \
  "$DIR/build/Windows/master/release/bin" \
  "$DIR/../../build/Windows/master/release/bin"
do
  if test -x "$dir/rxmrd"
  then
    rxmrd="$dir/rxmrd"
    break
  fi
done
if test -z "$rxmrd"
then
  echo "rxmrd not found"
  exit 1
fi
echo "Found: $rxmrd"

TORDIR="$DIR/rxmr-over-tor"
TORRC="$TORDIR/torrc"
HOSTNAMEFILE="$TORDIR/hostname"
echo "Creating configuration..."
mkdir -p "$TORDIR"
chmod 700 "$TORDIR"
rm -f "$TORRC"
cat << EOF > "$TORRC"
ControlSocket $TORDIR/control
ControlSocketsGroupWritable 1
CookieAuthentication 1
CookieAuthFile $TORDIR/control.authcookie
CookieAuthFileGroupReadable 1
HiddenServiceDir $TORDIR
HiddenServicePort 18880 127.0.0.1:18880
EOF

echo "Starting Tor..."
nohup tor -f "$TORRC" 2> "$TORDIR/tor.stderr" 1> "$TORDIR/tor.stdout" &
ready=0
for i in `seq 10`
do
  sleep 1
  if test -f "$HOSTNAMEFILE"
  then
    ready=1
    break
  fi
done
if test "$ready" = 0
then
  echo "Error starting Tor"
  cat "$TORDIR/tor.stdout"
  exit 1
fi

echo "Starting rxmrd..."
HOSTNAME=$(cat "$HOSTNAMEFILE")
"$rxmrd" \
  --anonymous-inbound "$HOSTNAME":18880,127.0.0.1:18880,25 --tx-proxy tor,127.0.0.1:9050,10 \
  --detach
ready=0
for i in `seq 10`
do
  sleep 1
  status=$("$rxmrd" status)
  echo "$status" | grep -q "Height:"
  if test $? = 0
  then
    ready=1
    break
  fi
done
if test "$ready" = 0
then
  echo "Error starting rxmrd"
  tail -n 400 "$HOME/.rxmr/rxmrd.log" | grep -Ev stacktrace\|"Error: Couldn't connect to daemon:" | tail -n 20
  exit 1
fi

echo "Ready. Your Tor hidden service is $HOSTNAME"
