#!/usr/bin/env bash
#This script help you export cucushift envs
#author: hasha@redhat.com
#set -o errexit
set -o nounset
set -o pipefail



print_usage() {
echo "$(basename "$0") - Generate cucushift vars
Usage: $(basename "$0") [options...]
Options:
  --dry-run         If specified, only print the vars that would be used by cucushift, without updating your shell script. (If you are first time to use the script, suggest copy the result of dryrun to your own var script. Ever since you can use --update-file directly)
  --update-file|-update  The script will update your exsiting var shell script you specified. Suggest you use the \$source(or .) cucushift_var.sh to run the script.
" >&2
}

update_file() {
    echo "input the path of your shell script:  (you can fix the value of shell_path, no need to input the shell_path everytime)"
    read shell_path
    sed -i -r "/ENV_OCP4_HOSTS/s/([a-Z|/b]+=)(.*)/\1$MARSTER:master:node,$LB:lb/" $shell_path
    sed -i -r "/ENV_OCP4_USER_MANAGER_USERS/s/([a-Z|/b]+=)(.*)/\1$USERS/" $shell_path
    sed -i -r "/admin_creds_spec/s|([a-Z|/b]+:)(.*)|\1 \"$KUBE_VIEWLINK\"|" $shell_path
    sed -i -r "/version/s/([a-Z|/b]+:)(.*)/\1 \"$VERSION\"/" $shell_path
    sed -i -r "/idp/s|([a-Z|/b]+:)(.*)|\1 \"$IDP\"|"  $shell_path
    sed -i -r "/admin_console_url/s|([a-Z|/b]+:)(.*)|\1 \"$CONSOLE_ROUTE\"|" $shell_path
    source $shell_path
    echo "Your cucushift envvars has been sourced if you run script by source command, you can run case directly!"

}
generate_cucushift_vars() {

  echo "+++++++++++++++++++++++cucushift variables+++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo "export BUSHSLICER_DEBUG_AFTER_FAIL=1"
  echo "export BUSHSLICER_DEFAULT_ENVIRONMENT=ocp4"
  echo "export OPENSHIFT_ENV_OCP4_HOSTS=$MARSTER:master:node,$LB:lb"
  echo "export OPENSHIFT_ENV_OCP4_USER_MANAGER_USERS=$USERS"
  echo "export BUSHSLICER_CONFIG='
  global:
    browser: chrome
  environments:
    ocp4:
      admin_creds_spec: \"$KUBE_VIEWLINK\"
      version: \"$VERSION\"
      idp: \"flexy-htpasswd-provider\"
      admin_console_url: \"$CONSOLE_ROUTE\"
'
"
 
}

init_var() {
  read -p "Please input kubeconfig view link(looks like ..artifact/workdir/install-dir/auth/kubeconfig/*view*/): " KUBE_VIEWLINK
  USER_VIEWLINK=$(echo $KUBE_VIEWLINK |sed -r "s|(^http.*artifact/)(.*)|\1users.spec/*view*/|")
  curl -k -o ./cucushift_kubeconfig $KUBE_VIEWLINK >& /dev/null
  curl -k -o ./cucushift_users $USER_VIEWLINK >& /dev/null
  user=$((RANDOM%50))
  USERS=$(cat ./cucushift_users | awk -F, 'OFS="," {print $"'$user'",$("'$user'"+1)}')
  echo "you will use these two users: $USERS"
  read -p "please input version you want running on (4.1/4.2/4.3/4.4): " VERSION
  CONSOLE_ROUTE=$(oc get route -n openshift-console --config=./cucushift_kubeconfig | awk  '$1 ~ /console/{print "https://"$2}')
  MARSTER=$(oc get node -l node-role.kubernetes.io/master --config=./cucushift_kubeconfig | awk 'NR==2{print $1}')
  LB=$(oc get infrastructures.config.openshift.io cluster -o 'jsonpath={.status.apiServerURL}' --config=./cucushift_kubeconfig | sed -e 's|^[^/]*//||' -e 's|:.*$||')
  IDP=flexy-htpasswd-provider
  rm ./cucushift_kubeconfig
  rm ./cucushift_users
}


for i in "$@"
do
case $i in
    --dry-run)
    init_var	    
    generate_cucushift_vars
    ;;
    -h|--help)
      print_usage
    ;;
    -update|--update-file)
      init_var
      update_file
    ;;
    *)
     print_usage
    ;;
esac
done
