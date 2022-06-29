#!/usr/bin/env sh

set +e

rdp()
{
  POSITIONAL_ARGS=()

  instance=
  port=3389
  zone=$ZONE
  project=$GOOGLE_CLOUD_PROJECT
  disable_connection_check=
  extra=

  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--project)
        project="$2"
        shift
        shift
      ;;
      -z|--zone)
        zone="$2"
        shift
        shift
      ;;
      -d|--disable-connection-check)
        disable_connection_check="--disable-connection-check"
        shift
      ;;
      --)
        shift;
        break
      ;;
      -*|--*)
        echo "Unknown option $1"
        return 1
      ;;
      *)
        POSITIONAL_ARGS+=("$1")
        shift
      ;;
    esac
  done

  instance=${POSITIONAL_ARGS[0]}
  extra="$@"

  iap-chain.sh $instance $port --project $project --zone $zone $disable_connection_check -- xfreerdp +clipboard +home-drive /kbd:0x00000407 /kbd-lang:0x0407 /dynamic-resolution /log-level:WARN /v:%SERVER% $extra 
}
