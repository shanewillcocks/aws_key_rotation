#--------------------------------------------------
# Update AWS access keys for octopus_provisioner
#--------------------------------------------------

# Just target dev in the first cut
iam_account=$(get_octopusvariable "octopus_iam_account")
url=$(get_octopusvariable "octopus_url")
target_account_name="${iam_account} - dev"
target=$(get_octopusvariable "target_space")
target_id=$(get_octopusvariable "target_space_id")
new_access_key=#{Octopus.Action[Rotate AWS Keys for Octopus].Output.new_access_key_id}
new_secret_access_key=#{Octopus.Action[Rotate AWS Keys for Octopus].Output.new_access_key_secret}
api_key=$(get_octopusvariable "odApiKey")

# DEBUG
echo "Got new Access Key: ${new_access_key}"
echo "Got new Secret Access key: ${new_secret_access_key}"

echo "Updating AWS key values for ${iam_account}"
# Create json payload
json_payload="{ \"AccountType\": \"AmazonWebServicesAccount\", \"AccessKey\": \"${new_access_key}\", \"SecretKey\": { \"HasValue\": \"True\", \"NewValue\": \"${new_secret_access_key}\" }, \"Name\": \"${target_account_name}\" }"
# Get list of all accounts for the space
accounts_url="${url}/api/Spaces-42/accounts?skip=0&take=100000"
echo "Getting a list of accounts for target ${target} from ${accounts_url}"
accounts_list=$(curl -s -H "X-Octopus-ApiKey: ${api_key}" "${accounts_url}")
accounts_total=$(echo ${accounts_list}|jq length)
echo "Retrieved ${accounts_total} accounts in Space ${target} with ID ${target_id}"
# Iterate through all non-null accounts
for ((count=0;  count < ${accounts_total}; ++count))
do
  account_name=$(echo $accounts_list|jq ".Items[$count].Name"|sed 's/\"//g')
  if [ "$account_name" != "null" ]; then
    account_id=$(echo $accounts_list|jq ".Items[$count].Id"|sed 's/\"//g')
    # Match found so update AWS keypair values
    if [ "${account_name}" == "${target_account_name}" ]; then
      echo "Matched account ${account_name} - updating AWS access keys"
      account_update=$(curl -s -H "X-Octopus-ApiKey: ${api_key}" -X PUT -d "${json_payload}" "${url}/api/${target_id}/accounts/${account_id}")
      rc=$?
      if [ ${rc} -eq 0 ]; then
        echo "Account update succeeded, return code ${rc}"
      else
        echo "Account update failed with return code: ${rc}"
        echo "Curl output: ${account_update}"
      fi
    else
      echo "Account ${account_name} not matched"
      # Not sure we need to create the account - adding for completeness but disabled
      # echo "Account ${account_name} not found in ${target_id}. Creating account"
      # account_create=$(curl -s -H "-Octopus-ApiKey: ${api_key}" -X POST -d "${json_payload}" "${url}/api/${target_id}/accounts/")
      # rc=$?
      # if [ ${rc} -eq 0 ]; then
        # echo "Account create succeeded"
      # else
        # echo "Account create failed with return code: ${rc}"
        # echo "Curl output: ${account_create}"
      # fi
    fi
  else
    echo "Skipping null account"
  fi
done
