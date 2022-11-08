#-----------------------------------------------------
# Update Terraform Account with new AWS access keys
#-----------------------------------------------------

# Hash to correlate workspace names and id values
declare -A target_workspaces
iam_account=$(get_octopusvariable "terraform_iam_account")
api_token=$(get_octopusvariable "tfe_api_token")
tfe_url=$(get_octopusvariable "terraform_url")
org=$(get_octopusvariable "org_name")

# 1. Get access key values from Step 1
aws_access_key_id="#{Octopus.Action[Rotate AWS Keys for Terraform].Output.current_access_key_id}"
new_aws_access_key_id="#{Octopus.Action[Rotate AWS Keys for Terraform].Output.new_access_key_id}"
new_aws_secret_key_id="#{Octopus.Action[Rotate AWS Keys for Terraform].Output.new_access_key_secret}"

# For debugging key values
debug () {
  echo "New Access Key ID is for ${iam_account} is ${new_aws_access_key_id}"
  echo "New Secret Key ID is for ${iam_account} is ${new_aws_secret_key_id}"
}
debug

# Define headers for TFE API calls
content_header="content-type: application/vnd.api+json"
auth_header="Authorization: Bearer ${api_token}"

# 2. Get all TFE workspaces and attempt to match AWS access keys
workspace_list=$(curl -s -H "${content_header}" -H "${auth_header}" -X GET "${tfe_url}/organizations/${org}/workspaces"|jq '.data')
workspace_count=$(echo ${workspace_list}|jq length)
echo "Got ${workspace_count} workspaces from Terraform, checking for AWS access keys"
for ((wcount=0; wcount < ${workspace_count}; ++wcount))
do
  workspace_name=$(echo ${workspace_list}|jq ".[$wcount].attributes.name"|sed 's/\"//g')
  workspace_id=$(echo ${workspace_list}|jq ".[$wcount].id"|sed 's/\"//g')
  workspace_vars=$(curl -s -H "${content_header}" -H "${auth_header}" -X GET "${tfe_url}/vars?filter%5Borganization%5D%5Bname%5D=${org}&filter%5Bworkspace%5D%5Bname%5D=${workspace_name}"|jq '.data')
  var_count=$(echo ${workspace_vars}| jq length)
  echo "Checking workspace ${workspace_name} (${workspace_id})"
  # Attempt to match AWS access key value
  for ((vcount=0; vcount < ${var_count}; ++vcount))
  do
    var_key=$(echo $workspace_vars|jq ".[$vcount].attributes.key"|sed 's/\"//g')
    var_value=$(echo $workspace_vars|jq ".[$vcount].attributes.value"|sed 's/\"//g')
    var_id=$(echo $workspace_vars|jq ".[$vcount].id"|sed 's/\"//g')
    if [ "${var_key}" == "AWS_ACCESS_KEY_ID" ] && [ "${var_value}" == "${aws_access_key_id}" ]; then
      target_workspaces[${workspace_name}]=${workspace_id}
    fi
  done
done
echo "Found ${#target_workspaces[@]} workspaces with matching AWS keys:"
for workspace in "${!target_workspaces[@]}"
do
  echo "Wokspace Name: ${workspace} ID: ${target_workspaces[$workspace]}"
done

# 3. For each target workspace, retrieve the target variable IDs for AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and update via API PATCH method
for workspace in "${!target_workspaces[@]}"
do
  workspace_vars=$(curl -s -H "${content_header}" -H "${auth_header}" -X GET "${tfe_url}/vars?filter%5Borganization%5D%5Bname%5D=${org}&filter%5Bworkspace%5D%5Bname%5D=${workspace}"|jq '.data')
  var_count=$(echo ${workspace_vars}| jq length)
  for ((vcount=0; vcount < ${var_count}; ++vcount))
  do
    var_key=$(echo $workspace_vars|jq ".[$vcount].attributes.key"|sed 's/\"//g')
    var_value=$(echo $workspace_vars|jq ".[$vcount].attributes.value"|sed 's/\"//g')
    var_id=$(echo $workspace_vars|jq ".[$vcount].id"|sed 's/\"//g')
    if [ "${var_key}" == "AWS_ACCESS_KEY_ID" ]; then
      echo "Attempting to update AWS access key for workspace ${target}"
      json_payload="{ \"data\": { \"id\": \"${var_id}\", \"attributes\": { \"value\": \"${new_aws_access_key_id}\" }, \"type\": \"vars\" } }"
      curl -s -H "${content_header}" -H "${auth_header}" -X PATCH -d "${json_payload}" "${tfe_url}/workspaces/${target_workspaces[$workspace]}/vars/${var_id}"
    fi
    if [ "${var_key}" == "AWS_SECRET_ACCESS_KEY" ]; then
      echo "Attempting to update AWS secret access key for workspace ${target}"
      json_payload="{ \"data\": { \"id\": \"${var_id}\", \"attributes\": { \"value\": \"${new_aws_secret_key_id}\" }, \"type\": \"vars\" } }"
      curl -s -H "${content_header}" -H "${auth_header}" -X PATCH -d "${json_payload}" "${tfe_url}/workspaces/${target_workspaces[$workspace]}/vars/${var_id}"
    fi
  done
done
