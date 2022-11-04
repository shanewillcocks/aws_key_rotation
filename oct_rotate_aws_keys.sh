#---------------------------------------------------
# Rotate AWS access keys for octopus_provisioner
#---------------------------------------------------
export https_proxy=http://proxy:10568
export no_proxy="localhost"
export AWS_ACCESS_KEY_ID=#{AWS_Account.AccessKey}
export AWS_SECRET_ACCESS_KEY=#{AWS_Account.SecretKey}
export AWS_REGION=#{AWS_Region}

iam_account=$(get_octopusvariable "octopus_iam_account")

# 1. Retrieve existing active accces key data for IAM account
get_active_keys () {
  echo "Querying AWS access keys for ${iam_account}"
  active_key=$(aws iam list-access-keys --user-name ${iam_account} --query 'AccessKeyMetadata[?Status==`Active`]'| jq -r '.[].AccessKeyId')
  echo "Active access key for ${iam_account} is ${active_key}"
}

# 2. Retrieve existing inactive key
delete_inactive_key () {
  inactive_key=$(aws iam list-access-keys --user-name ${iam_account} --query 'AccessKeyMetadata[?Status==`Inactive`]'| jq -r '.[].AccessKeyId')
  if [ "${inactive_key}" == "" ]; then
    echo "No inactive access keys found for ${iam_account}"
  else
    echo "Deleting inactive access key for ${iam_account}: ${inactive_key}"
    aws iam delete-access-key --access-key-id ${inactive_key} --user-name ${iam_account} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -eq 0 ]; then
      echo "Delete succeeded"
    else
      echo "Delete failed: ${rc}"
    fi
  fi
}

# 3. Create a new keypair and set output vars
create_new_keys () {
  echo "Creating new access key for ${iam_account}"
  new_key_json=$(aws iam create-access-key --user-name ${iam_account})
  new_access_key_id=$(echo ${new_key_json} | jq -r '.[].AccessKeyId')
  new_secret_key_id=$(echo ${new_key_json} | jq -r '.[].SecretAccessKey')
  #DEBUG
  echo ${new_key_json}
  echo "AWS output: New access key is ${new_access_key_id}"
  echo "AWS output: New secret access key is ${new_secret_key_id}"

  set_octopusvariable "current_access_key_id" "${active_key}"
  set_octopusvariable "new_access_key_id" "${new_access_key_id}"
  set_octopusvariable "new_access_key_secret" "${new_secret_key_id}"
}

# 4. Set previous active key as inactive
inactivate_key () {
  aws iam update-access-key --access-key-id ${active_key} --status Inactive --user-name ${iam_account}
}

get_active_keys
create_new_keys
delete_inactive_key
inactivate_key
echo "Key rotation script complete for ${iam_account}"
