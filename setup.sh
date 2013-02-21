#!/bin/bash
hwclock --systohc
crontab -l > /tmp/dump
echo "0 0 * * * /opt/openmrs-backup-tools/openmrs_backup.sh -e" >> /tmp/dump
crontab /tmp/dump