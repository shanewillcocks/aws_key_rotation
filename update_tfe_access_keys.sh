#-----------------------------------------------------
# Update Terraform Account with new AWS access keys
#-----------------------------------------------------
target_workspaces=""
echo "New Access Key ID is for ${target_iam_account_name} in AWS account ${AWS_Account} is" #{Octopus.Action[Rotate terraform_provisioner Keys in AWS].Output.new_access_key_id}
echo "New Secret Key ID is for ${target_iam_account_name} in AWS account ${AWS_Account} is" #{Octopus.Action[Rotate terraform_provisioner Keys in AWS].Output.new_access_key_secret}
# Get access key values from Step 1
target_aws_access_key_id_value="#{Octopus.Action[Rotate terraform_provisioner Keys in AWS].Output.current_access_key_id}"
target_aws_access_key_id_new_value="#{Octopus.Action[Rotate terraform_provisioner Keys in AWS].Output.new_access_key_id}"
target_aws_secret_key_id_new_value="#{Octopus.Action[Rotate terraform_provisioner Keys in AWS].Output.new_access_key_secret}"
# Define headers for TFE API calls
content_header="content-type: application/vnd.api+json"
auth_header="Authorization: Bearer ${tfe_api_token}"

# 1. Get all TFE workspaces
workspace_list=$(curl -s -H "${content_header}" -H "${auth_header}" -X GET "${terraform_url}/organizations/${org_name}/workspaces"|jq '.data')
workspace_count=$(echo ${workspace_list}|jq length)
echo "Got ${workspace_count} workspaces from Terraform"
# DEBUG
# Workspace names: echo ${workspace_list}|jq '.[].attributes.name'
# Workspace IDs: echo ${workspace_list}|jq '.[].id'

# 2. For each workspace found, enumerate variables and build an array of targets that match the value of AWS_ACCESS_KEY_ID
for ((wcount=0; wcount < ${workspace_count}; ++wcount))
do
  workspace_name=$(echo ${workspace_list}|jq ".[$wcount].attributes.name"|sed 's/\"//g')
  workspace_id=$(echo ${workspace_list}|jq ".[$wcount].id"|sed 's/\"//g')
  workspace_vars=$(curl -s -H "${content_header}" -H "${auth_header}" -X GET "${terraform_url}/vars?filter%5Borganization%5D%5Bname%5D=${org_name}&filter%5Bworkspace%5D%5Bname%5D=${workspace_name}"|jq '.data')
  # DEBUG
  # var names: echo $workspace_vars|jq '.[].attributes.key'
  # var values: echo $workspace_vars|jq '.[].attributes.value'
  var_count=$(echo ${workspace_vars}| jq length)
  echo "Got ${var_count} variables for ${workspace_name}, checking for AWS access keys"
  for ((vcount=0; vcount < ${var_count}; ++vcount))
  do
    var_key=$(echo $workspace_vars|jq ".[$vcount].attributes.key"|sed 's/\"//g')
    var_value=$(echo $workspace_vars|jq ".[$vcount].attributes.value"|sed 's/\"//g') 
    var_id=$(echo $workspace_vars|jq ".[$vcount].attributes.id"|sed 's/\"//g')
    if [ "${var_key}" == "AWS_ACCESS_KEY_ID" ] && [ "${var_value}" == "${target_aws_access_key_id_value}" ]; then
      echo "Found matching AWS access keys in workspace ${workspace_name}"
      target_workspaces+=" ${workspace_name}" 
    fi
  done
done 

# 3. For each target workspace update AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
for target in $target_workspaces
do
  workspace_vars=$(curl -s -H "${content_header}" -H "${auth_header}" -X GET "${terraform_url}/vars?filter%5Borganization%5D%5Bname%5D=${org_name}&filter%5Bworkspace%5D%5Bname%5D=${target}"|jq '.data')
  var_count=$(echo ${workspace_vars}| jq length)
  for ((vcount=0; vcount < ${var_count}; ++vcount))
  do
    var_key=$(echo $workspace_vars|jq ".[$vcount].attributes.key"|sed 's/\"//g')
    var_value=$(echo $workspace_vars|jq ".[$vcount].attributes.value"|sed 's/\"//g') 
    var_id=$(echo $workspace_vars|jq ".[$vcount].attributes.id"|sed 's/\"//g')
    if [ "${var_key}" == "AWS_ACCESS_KEY_ID" ]; then
      echo "Attempting to update AWS access key for workspace ${target}"
      json_payload="{ \"data\": { \"id\":\"${var_id}\", \"attributes\": { \"value\": \"${target_aws_access_key_id_new_value}\" }, \"type\": \"vars\" } }"
      curl -s -H "${content_header}" -H "${auth_header}" -X PATCH -d "${json_payload}" "${terraform_url}/vars/${var_id}"
    fi 
    if [ "${var_key}" == "AWS_SECRET_ACCESS_KEY_ID" ]; then 
      echo "Attempting to update AWS secret access key for workspace ${target}"
      json_payload="{ \"data\": { \"id\":\"${var_id}\", \"attributes\": { \"value\": \"${target_aws_secret_key_id_new_value}\" }, \"type\": \"vars\" } }"
      curl -s -H "${content_header}" -H "${auth_header}" -X PATCH -d "${json_payload}" "${terraform_url}/vars/${var_id}"
    fi 
  done
done
