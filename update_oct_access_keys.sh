#--------------------------------------
# Update AWS access keys for Octopus
#--------------------------------------
target_account_name="${oct_iam_account}"
new_access_key=#{Octopus.Action[Rotate octopus_provisioner Keys in AWS].Output.new_access_key_id}
new_secret_access_key=#{Octopus.Action[Rotate octopus_provisioner Keys in AWS].Output.new_access_key_secret} 

echo "Updating Infrastructure Account for ${oct_iam_account}"
# Create json payload
json_payload="{ \"AccountType\": \"AmazonWebServicesAccount\", \"AccessKey\": \"${new_access_key}\", \"SecretKey\" { \"HasValue\": = \"True\", \"NewValue\": \"${new_secret_access_key}\" }, \"Name\": \"${target_account_name}\" }"
# Get list of all accounts for the space
accounts_url="${octopus_url}/api/Spaces-00/accounts?skip=0&take=100000"
echo "Accounts URL is ${accounts_url} - getting a list of accounts for ${target_space}"
# Returns json
accounts_list=$(curl -s -H "X-Octopus-ApiKey: ${oct_api_key}" "${accounts_url}")
accounts_total=$(echo ${accounts_list}|jq length)
echo "Retrieved ${accounts_total} accounts in ${target_space}"
for ((count=0;  count < ${accounts_total}; ++count))
do
  account_name=$(echo $accounts_list|jq ".Items[$count].Name"|sed 's/\"//g')
  account_id=$(echo $accounts_list|jq ".Items[$count].Id"|sed 's/\"//g')
  if [ "${account_name}" == "${target_account_name}" ]; then
    echo "Updating AWS access keys for ${account_name}"
    account_update=$(curl -s -H "X-Octopus-ApiKey: ${oct_api_key}" -X PUT -d "${json_payload}" "${octopus_url}/api/Spaces-00/accounts/${account_id}")
    rc=$?
    if [ ${rc} -eq 0 ]; then 
      echo "Account update succeeded"
    else 
      echo "Account update failed with return code: ${rc}"
      echo "Curl output: ${account_update}"
    fi
  else 
    # Not sure we need to create the account - adding for completeness
    echo "Account ${target_account_name} not found in ${space_name}. Creating account"
    account_create=$(curl -s -H "-Octopus-ApiKey: ${oct_api_key}" -X POST -d "${json_payload}" "${octopus_url}/api/Spaces-00/accounts/")
    rc=$?
    if [ ${rc} -eq 0 ]; then 
      echo "Account create succeeded"
    else 
      echo "Account create failed with return code: ${rc}"
      echo "Curl output: ${account_update}"
    fi 
  fi  
done
