# the id is passed as the first argument to the script
DASHBOARD_ID=$1
# the custom name for the file is passed as the second argument to the script
# if not passed we will use the dashboard id as the file name
if [ -z "$2" ]; then
  DASHBOARD_FILE=$1
else
  DASHBOARD_FILE=$2
fi

# the output file is passed as the second argument to the script
curl -o monitoring/config/grafana/dashboards/${DASHBOARD_FILE}.json https://grafana.com/api/dashboards/${DASHBOARD_ID}/revisions/latest/download