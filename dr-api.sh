#!/usr/bin/env bash

PROJECT_CPD_INST_OPERANDS=cpd
ROUTE=cpd-wkc.apps.cpd510vz.cp.fyre.ibm.com
admin_username=sanjitc
admin_apikey=MBtAkTm57z9SSUJltjBwoaeDLDVcw1t4R58Omta9

PROJECT=779ab788-dd59-4b1c-a735-928c232916a9

#------- Get the user authentication token

AUTH_TOKEN=$(
  curl -k -X POST \
    -H "Content-Type: application/json" \
    -d "{
          \"username\": \"${admin_username}\",
          \"api_key\": \"${admin_apikey}\"
        }" \
    "https://${ROUTE}/icp4d-api/v1/authorize" \
  | jq -r '.token'
)


#------- STEP01: Create a data refinery flow

curl -k -X POST -H "Authorization: Bearer $AUTH_TOKEN" --location "https://${ROUTE}/v2/data_flow_spark?project_id=${PROJECT}" \
--header 'Content-Type: application/json' \
--data-raw '{
   "name":"genz_customer_flow",
   "description":"Extract data from asset",
   "pipeline":{
      "version":"1.0",
      "doc_type":"pipeline",
      "app_data":{
         "shaperCreated":true,
         "replace_space_by_dot":true
      },
      "primary_pipeline":"pipeline1",
      "pipelines":[
         {
            "id":"pipeline1",
            "nodes":[
               {
                  "id":"source1",
                  "app_data":{
                     "sampling":{
                        "type":"topRows",
                        "size":10000
                     }
                  },
                  "data_asset":{
                     "properties":{
			"select_statement":"select * from CUST_TABLES_0001_K020ROWS_250COLS.customer where YEAR(date_of_birth) >= 2000"
                     },
                     "ref":"420c3b60-699c-4a65-b04b-62c09de1b30a",
                     "app_data":{
                        "dataset_name":"GenZ-Customer"
                     }
                  },
                  "type":"binding",
                  "output":{
                     "id":"source1output"
                  }
               },
               {
                  "id":"executionid_0",
                  "type":"execution_node",
                  "op":"com.ibm.wdp.transformer.FreeformCode",
                  "app_data":{
                     "uiParams":{
                        "key":"filter",
                        "code":"filter(`GENDER`==\"Female\")",
                        "args":{
                           "conditions":[
                              {
                                 "column":"GENDER",
                                 "actualType":"String",
                                 "operator":"==",
                                 "value":"Female",
                                 "valueOption":"value",
                                 "replaceValue":""
                              }
                           ],
                           "version":1
                        }
                     }
                  },
                  "parameters":{
                     "FREEFORM_CODE":"filter(`GENDER`==\"Female\")"
                  },
                  "inputs":[
                     {
                        "id":"inputPort1",
                        "links":[
                           {
                              "node_id_ref":"source1",
                              "port_id_ref":"source1output"
                           }
                        ]
                     }
                  ],
                  "outputs":[
                     {
                        "id":"outputPort1"
                     }
                  ]
               },
               {
                  "data_asset":{
                     "properties":{
                        "name":"genz-customer-refinded-data",
                        "file_format":"csv",
                        "mode":"overwrite",
                        "first_line_header":true
                     },
                     "app_data":{

                     }
                  },
                  "id":"target1",
                  "type":"binding",
                  "input":{
                     "id":"targetInput1",
                     "link":{
                        "node_id_ref":"executionid_0",
                        "port_id_ref":"outputPort1"
                     }
                  }
               }
            ],
            "runtime":"Spark"
         }
      ]
   }
}'


#------- STEP02: Create a data refinery flow job
FLOW=$(
  curl -k -X POST \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    "https://${ROUTE}/v2/asset_types/asset/search?project_id=${PROJECT}" \
    -d '{
      "query": "asset.name:\"genz_customer_flow\"",
      "limit": 100
    }' \
  | jq -r '.results[] | select(.metadata.name=="genz_customer_flow") | .metadata.asset_id'
)


curl -k -X POST -H "Authorization: Bearer $AUTH_TOKEN" --location "https://${ROUTE}/v2/jobs?project_id=${PROJECT}" \
--header 'Content-Type: application/json' \
--data @<(cat <<EOF
{
  "job": {
    "name": "genz-customer-flow-job",
    "description": "Data flow job for GenZ-Customer",
    "asset_ref": "${FLOW}",
    "configuration": {
      "env_id": "shaper_rruntime",
      "env_name": "Default Data Refinery XS"
    }
  }
}
EOF
)

#------- STEP03: Run a data refinery flow job
JOB=$(
  curl -k -X GET \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    --location "https://${ROUTE}/v2/jobs?project_id=${PROJECT}&name=GenZ-Customer-flow-job" \
  | jq -r '.results[]
           | select(.metadata.name=="genz-customer-flow-job")
           | .metadata.asset_id'
)

curl -k -X POST -H "Authorization: Bearer $AUTH_TOKEN" --location "https://${ROUTE}/v2/jobs/${JOB}/runs?project_id=${PROJECT}" \
--header 'Content-Type: application/json' \
--data '{
    "job_run": {}
}'


