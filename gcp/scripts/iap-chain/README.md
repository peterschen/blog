# iap-chain.sh #

Script that enables command chaining for IAP tunnels established through `gcloud compute start-iap-tunnel`.

## Usage ##
```bash
iap-chain.sh INSTANCE_NAME INSTANCE_PORT [-z|--zone ZONE] -- CHAIN_COMMAND
```

To allow for automation arguments can also be passed by setting environmental variables before invoking `iap-chain.sh`:

```bash
  INSTANCE_NAME
  INSTANCE_PORT
  ZONE
  CHAIN_COMMAND
```

IAP will dynamically allocate local free port. To make this port available to the chain command use `%SERVER%` which will be automatically replaced before calling the chain command.

### Examples ###

```bash
iap-chain.sh my-windows-box 3389 -- xfreerdp /v:%SERVER%
```

## Best practices ##

`iap-chain.sh` is designed to be generically compatible with chain commands. In some cases this means that the command line to call `iap-chain.sh` may become long. Here are some examples that may help by creating aliases or functions:

### freerdp ###

This function can be sourced in `.bash_profile` and uses `iap-chain.sh` to call `xfreerdp` after the IAP tunnel has been established.

```bash
#!/usr/bin/env sh
set +e

rdp()
{
    POSITIONAL_ARGS=()

    instance=
    port=3389
    zone=$ZONE
    extra=

    while [[ $# -gt 0 ]]; do
        case $1 in
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

    iap-chain.sh $instance $port -z $zone -- xfreerdp +clipboard +home-drive /kbd:0x00000407 /kbd-lang:0x0407 /dynamic-resolution /log-level:WARN /v:%SERVER% $extra    
}
```