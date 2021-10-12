#!/bin/bash
git commit -a -m init
git clean -dfx
gbp buildpackage --git-ignore-new --git-export-dir=../cluster-artifacts --git-debian-branch=master --git-upstream-branch=master --git-upstream-tree=master 

