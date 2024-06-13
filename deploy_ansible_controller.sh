#!/bin/bash

set -e

ShowHelp() {
    if [ "$1" == "--help" ]; then
        echo "This script will install ansible, modules, and either init a git repo or build directory structure and local inventory"
        echo "Options can be configured by copy config.ini into a config.ini.local file and modifying the values"
        echo "Needs to run as root"
        echo "Needs to be connected to internet"
        exit 0
    fi
}

ShowInitialMessage() {
    redTextColor='\033[0;31m'

    noTextColor='\033[0m'

    echo "This script will install ansible, modules, and either init git repo or build directory structure and local inventory"
    echo -e "${redTextColor}Make sure config.ini o config.ini.local has the correct options${noTextColor}"
    echo "Waiting thirty seconds for user to Cntl-C to cancel or Enter to continue"

    timerDurationSeconds=30

    # Loop until the countdown is complete or Enter key is pressed
    while [ $SECONDS -lt $timerDurationSeconds ]; do
        echo $((timerDurationSeconds--))
        # The double bar is because the read command will return a non-zero exit code if it times out
        read -t 1 -N 1 -s input || true
        if [ "$input" == $'\x0a' ]; then
            break
        fi
    done

    printf '\n'
}

InvokeInitialChecks() {
    echo "Action: performing initial checks"

    if [ ! "$(id -u)" -eq 0 ]; then
        echo "Script must be run as root"
        exit 1
    fi

    if [ ! -d "$ansibleStructureDirectory" ]; then
        echo "Ansible structure directory does not exist already"
        exit 1
    fi

    if ! $(curl -k -s -o /dev/null https://github.com); then
        echo "Not connected to the internet"
        exit 1
    fi

}

InstallSystemDependencies() {
    echo "Action: install system dependencies"

    apt update || true

    for systemApt in "${systemApts[@]}"; do
        apt install -y "$systemApt"
    done
}

InstallAnsible() {
    echo "Action: installing ansible"

    apt update || true

    for ansibleApt in "${ansibleApts[@]}"; do
        apt install -y "$ansibleApt"
    done
    
    if [ "$createGitRepo" == true ]; then
        git init "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/
    else
        mkdir -p "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/
    fi

    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/
    
    rm -Rf ./.venv
    virtualenv ./.venv

    source ./.venv/bin/activate

    pip3 install ansible-core==$ansibleInstallVersion
}

CreateAnsibleDirectoryStructure() {
    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/
    for directory in "${ansibleDirectories[@]}"; do
        mkdir -p ./"$directory"
        touch ./"$directory"/.gitkeep
    done

    if [ ! -f ./.gitignore ]; then
        touch ./.gitignore 
            for gitIgnoreFile in "${gitIgnoreFiles[@]}"; do
                 echo "$gitIgnoreFile" >> ./.gitignore
             done
    fi
    


}

InvokeRequirementsDoc() {
    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/

    source ./.venv/bin/activate

    if [ ! -f ./requirements.yml ]; then
        echo "collections:" > ./requirements.yml    
        for ansibleCollection in "${ansibleCollections[@]}"; do
            echo "  - name: $ansibleCollection" >> ./requirements.yml
        done
    fi

    for ansibleCollectionsPythonModule in "${ansibleCollectionsPythonModules[@]}"; do
        pip3 install "$ansibleCollectionsPythonModule"
    done

    if [ ! -f ./requirements.yml ]; then
        exit 1
        echo "Check: requirements.yml file not found"
    fi

    ansible-galaxy collection install -r ./requirements.yml
}

CreateAnsibleLocalInventory() {
    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/
    cat << EOF > ./inventory/local.yml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: $ansibleStructureDirectory/$ansibleStructureTopDir/.venv/bin/python3
EOF
}

CreateAnsibleCfg() {
    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/

    if [ ! -f ./ansible.cfg ]; then
    cat << "EOF" > ./ansible.cfg
[defaults]
gathering = smart
host_key_checking = false
scp_if_ssh=True
fact_caching = jsonfile
fact_caching_connection = cache_facts
fact_caching_timeout = 0
collections_path = collections
inventory = inventory
callback_plugins = ~/.ansible/plugins/callback:/usr/share/ansible/plugins/callback
timeout = 30

# Use the YAML callback plugin to pretty print and not show skipped hosts or tasks
#stdout_callback = yaml
display_skipped_hosts = no
# Use the stdout_callback when running ad-hoc commands to pretty print
bin_ansible_callbacks = True

[inventory]
cache_connection = cache_inventory
enable_plugins = constructed, yaml, ini, auto
any_unparsed_is_failed = true
EOF
    fi
}

CreateApb() {
    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/
    
    if [ !  -f ./apb.sh ]; then
    cat << "EOF" >  apb.sh
#!/bin/bash

if [ $# -eq 0 ]
then
    echo "Argument should be ansible playbook name"
    exit
fi

# Always make sure the script runs from the directory this script is located
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
source ./.venv/bin/activate
ansible-playbook $1 --skip-tags "out" --ask-become-pass --ask-vault-pass

EOF
    fi
    chmod +x ./apb.sh
}


InstallAnsibleCommon() {
    echo "Action: copying and installing ansible common"

    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/
    git clone https://github.com/cymcore/ansible_common.git 
    cd ./ansible_common
    chmod +x ./install_ansible_common.sh
    source ./install_ansible_common.sh
}

InstallCymCert() {
    echo "Action: installing cym cert"

    curl -k -s -o /usr/local/share/ca-certificates/cym.crt \
    https://raw.githubusercontent.com/cymcore/cymcore_common/main/cymca.crt

    update-ca-certificates
}

InvokeFinishTasks() {
    cd "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/

    echo "Action: finishing tasks"

    deactivate

    chown -R "$ansibleUserDirectoryOwner":"$ansibleUserDirectoryOwner" "$ansibleStructureDirectory"/"$ansibleStructureTopDir"/

    echo "Script completed successfully"
}

InvokeSourceConfig() {
    if [ -f config.ini.local ]; then
        source config.ini.local
    else
        source config.ini
    fi
}
### Main ###
ShowHelp

InvokeSourceConfig

ShowInitialMessage

InvokeInitialChecks

InstallSystemDependencies

InstallAnsible

CreateAnsibleDirectoryStructure

CreateAnsibleCfg

CreateAnsibleLocalInventory

CreateApb

InstallAnsibleCommon

InvokeRequirementsDoc

InvokeFinishTasks

# TODO - run the ansibe playbook to finish installing the control node if present