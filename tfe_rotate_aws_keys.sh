#!/bin/bash

iam_account="tfe_provisioner"

# Retrieve existing active accces key data for IAM account
active_key=$(aws iam list-access-keys --user-name ${iam_account} --query 'AccessKeyMetadata[?Status==`Active`]'| jq -r '.[].AccessKeyId')
echo "Active access key for ${iam_account} is ${active_key}"

# Retrieve existing inactive accces key data
inactive_key=$(aws iam list-access-keys --user-name ${iam_account} --query 'AccessKeyMetadata[?Status==`Inactive`]'| jq -r '.[].AccessKeyId')

# Delete current inactive key if present
if [ "${inactive_key}" == "" ]; then
  echo "Inactive access key for ${iam_account} was not found, skipping deletion"            
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

# Create new key
echo "Creating new access key for ${iam_account}"
new_key=$(aws iam create-access-key --user-name ${iam_account})

Set-OctopusVariable -name "currentAccessKeyID" -value ${active_key}
Set-OctopusVariable -name "newAccessKeyID" -value $(echo ${new_key} | jq -r '.[].AccessKeyId')
Set-OctopusVariable -name "newAccessKeySecret" -value $(echo ${new_key} | jq -r '.[].SecretAccessKey')
Set-OctopusVariable -name "userName" -value ${iam_account}

# Set oldest active key as inactive
aws iam update-access-key --access-key-id ${active_key} --status Inactive --user-name ${iam_account} >/dev/null 2>&1

# Retrieve existing active accces key data for IAM account
active_key=$(aws iam list-access-keys --user-name ${terraform_iam_account} --query 'AccessKeyMetadata[?Status==`Active`]'| jq -r '.[].AccessKeyId')
echo "Active access key for ${terraform_iam_account} is ${active_key}"

# Retrieve existing inactive accces key data
inactive_key=$(aws iam list-access-keys --user-name ${terraform_iam_account} --query 'AccessKeyMetadata[?Status==`Inactive`]'| jq -r '.[].AccessKeyId')

# Delete current inactive key if present
if [ "${inactive_key}" == "" ]; then
  echo "Inactive access key for ${terraform_iam_account} was not found, skipping deletion"            
else
  echo "Deleting inactive access key for ${terraform_iam_account}: ${inactive_key}"
  aws iam delete-access-key --access-key-id ${inactive_key} --user-name ${terraform_iam_account} >/dev/null 2>&1
  rc=$? 
  if [ ${rc} -eq 0 ]; then 
    echo "Delete succeeded"
  else  
    echo "Delete failed: ${rc}"
  fi 
fi

# Create new key
echo "Creating new access key for ${terraform_iam_account}"
new_key=$(aws iam create-access-key --user-name ${terraform_iam_account})

Set-OctopusVariable -name "current_access_key_id" -value ${active_key}
Set-OctopusVariable -name "new_access_key_id" -value $(echo ${new_key} | jq -r '.[].AccessKeyId')
Set-OctopusVariable -name "new_access_key_secret" -value $(echo ${new_key} | jq -r '.[].SecretAccessKey')
Set-OctopusVariable -name "user_name" -value ${terraform_iam_account}

# Set oldest active key as inactive
aws iam update-access-key --access-key-id ${active_key} --status Inactive --user-name ${terraform_iam_account} >/dev/null 2>&1

