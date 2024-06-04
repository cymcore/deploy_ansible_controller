Summary
------------
This script will install ansible, modules, and either init git repo or build directory structure and local inventory
It will handle two scenarios, a completely new ansible controller or installing venv and modules into an existing ansible directory structure

Configuration
--------------
1) tested with ubuntu 22.04 and debian 12
2) default config variables are in config.ini, but if a config.ini.local is present it will use that (e.g. customizations)
3) generally only used one time to start a new ansible git repo
4) the config.ini variable ansibleStructureDirectory represent the directory to install ansible variable ansibleStructureTopDir into
4a) meaning ansibleStructureTopDir is a child to ansibleStructureDirectory

Instructions
------------
1) use --help
2) the default is not to init a git repo - change in config file
3) download the ansible repo first if you only want to reinitialize the python and collections

Improvements
----------------



Issues
-------



ansibleStructureDirectory=/root

ansibleUserDirectoryOwner=root

ansibleStructureTopDir=ansible