#!/bin/bash

function check_upload_status()
{
  request_url="${sn_instance}/api/sn_cdm/applications/deployables/exports/$1/status"
  state="new"
  counter=0

  while [[ ${state} != "completed" ]] && [[ ${counter} -le 30 ]]; do
    response=$(curl -s -X GET ${request_url} -u ${sn_user}:${sn_password})
    echo ${response}
    state=$(echo ${response}|jq -r ".result.state")
    
    counter=$((counter+1))
    sleep 1
  done

  echo ${response}

  if [[ $(echo ${response}|jq -r ".result.exporter_result.state") == "failure" ]]; then
    echo "An error occurred during exporter execution:"
    echo ${response}|jq -r ".result.exporter_result.errors"
    echo "Aborting..."
    exit 1
  elif [[ ${counter} -gt 30 ]]; then
    echo "Timeout expired, please check manually..."
    exit 1
  fi

  get_exporter_content $1
}

function get_exporter_content()
{
  request_url="${sn_instance}/api/sn_cdm/applications/deployables/exports/$1/content"
  response=$(curl -s -X GET ${request_url} -u ${sn_user}:${sn_password})
  
  content=$(echo ${response}|jq -r ".result.exporter_result")
  echo ${content}
  echo "export_content<<EOF" >> $GITHUB_OUTPUT
  echo "${content}" >> $GITHUB_OUTPUT
  echo "EOF" >> $GITHUB_OUTPUT
}

declare sn_instance=$1
declare sn_user=$2
declare sn_password=$3

#request_url="${sn_instance}/api/sn_cdm/applications/deployables/exports?appName=$4&exporterName=$5&deployableName=$6&dataFormat=$7"
request_url="${sn_instance}/api/sn_cdm/applications/deployables/exports"
parameters="--data-urlencode appName=$4 --data-urlencode exporterName=$5 --data-urlencode deployableName=$6 --data-urlencode dataFormat=$7"

if [[ $8 != "" ]]; then
  parameters="${parameters} --data-urlencode snapshot=$8"
fi

if [[ $9 != "" ]]; then
  parameters="${parameters} --data-urlencode additional_deployables=$9"
fi

if [[ ${10} != "" ]]; then
  parameters="${parameters} --data-urlencode args=${10}"
fi

response=$(curl -X POST ${request_url} ${parameters} -u ${sn_user}:${sn_password} -H "Content-Type: application/x-www-form-urlencoded")

if [[ $(echo ${response}|jq -r ".error") != "null" ]]; then
  echo "An error occurred during upload:"
  echo ${response}|jq -r ".error.message"
  echo "Aborting..."
  exit 1
fi

echo ${response}
export_id=$(echo ${response}|jq -r ".result.export_id")

check_upload_status ${export_id}
