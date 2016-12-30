#!/bin/sh
packages=$(ls -1 *.rpm | sed 's/-[0-9].*//')
inst_candidates=""
for I in $packages; do
    rpm -q $I > /dev/null
    if [ $? -eq 0 ]; then
        inst_candidate=$(find . -iname "$I-[0-9]*.rpm")
        echo Package $I is installed, replacement candidate is $inst_candidate
        inst_candidates+=" $inst_candidate"
    fi
done
echo
echo Please run the following command to install the patched kernels:
echo "yum reinstall $inst_candidates"
