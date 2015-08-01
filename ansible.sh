#!/bin/bash -eux
sudo easy_install pip
sudo yum -y install gcc
sudo yum -y install python-devel.x86_64
sudo pip install ansible
