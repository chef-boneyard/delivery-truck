#!/bin/bash

CURR_DIR="$(dirname "$0")"
case "$1" in

    "enable") echo "Switching to Sandbox Config"
              rm .delivery/config.json
              cp .delivery/sandbox.json .delivery/config.json
              git remote rename delivery delivery-live
              git remote rename delivery-sbox delivery
              ;;
    "disable") echo "Switching to Live Config"
               rm .delivery/config.json
               cp .delivery/live.json .delivery/config.json
               git remote rename delivery delivery-sbox
               git remote rename delivery-live delivery
               ;;
esac
