#!/bin/bash

MIX_ENV=prod mix compile.protocols

while true; do
    MIX_ENV=prod elixir --erl "+K true +A 32" -pa _build/dev/consolidated/ -S mix run --no-halt
    sleep 0.2
done