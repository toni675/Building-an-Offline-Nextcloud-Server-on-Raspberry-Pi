#!/bin/bash
# Verify system integrity and log results

LOGFILE=/var/log/integrity-check.log

echo "==== Integrity Check: $(date) ====" | tee -a $LOGFILE
sha256sum -c /root/integrity-baseline.sha256 2>&1 | tee -a $LOGFILE
echo "" | tee -a $LOGFILE
