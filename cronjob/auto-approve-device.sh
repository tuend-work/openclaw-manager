#!/bin/bash
PENDING=$(openclaw devices list --json 2>/dev/null | grep -c '"status":"pending"')
if [ "$PENDING" -gt 0 ]; then
  openclaw devices approve --latest
fi