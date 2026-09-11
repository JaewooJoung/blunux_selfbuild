#!/bin/bash

# 1. 기존 디렉터리 삭제
rm -rf ./blnx2sb/

# 2. 압축 해제
bsdtar -xjvf blnx2.tar.bz2
