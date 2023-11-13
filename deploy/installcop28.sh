#!/bin/bash
#check if the user is logged in to azure if it is not logged in then we ask the user to login

clear
#check if prompt flow is installed
echo "IMPORTANT. Make sure you have purged all your Open AI and ContentSafety resources before running this script. Otherwise, the script will fail because if using MCAPS subscriptions we have very limited # of resources."
read -p "Press enter to continue..."	

if [ $(pip list | grep "promptflow" | wc -l) -eq 0 ]; then
  echo "promptflow is not installed, installing promptflow..."
  pip install promptflow
else
  echo "promptflow is installed!"
fi


if [ $(az account show | grep "user" | wc -l) -eq 0 ]; then
  echo "you are not logged in to your azure account, please log in first using az login command!"
  exit 1
else
  echo "you are logged in to your azure account! we can continue"
  #print the subscription id
  SUBSCRIPTION_ID=$(az account show --query id --output tsv)
  echo "your subscription id is: $SUBSCRIPTION_ID"
fi
while true
do
  echo "1. Install Cop28 components"
  echo "2. Exit"
  echo -n "Please enter an option: "
  read option

  case $option in
    1)
      echo "Installing Cop28 components..."
      # Add your Azure CLI commands for installing Cop28 components here
      
      RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
      #RESOURCE_GROUP_NAME="cop28-rg-$RANDOM_STRING"      
      RESOURCE_GROUP_NAME="cop28-rg"      
      LOCATION="eastus"
      #INFORMING THE USER THAT WE ARE CREATING A RESOURCE GROUP
        echo "Creating resource group $RESOURCE_GROUP_NAME in $LOCATION..."
        #CLI SCRIPT TO CREATE THE LOCATION
        az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

      # ask if the user wants to reuse an existing opeani resource
        echo -n "Do you want to reuse an existing Open AI resource? (y/n): "
        #if the user selects yes, then I ask for the Open AI resource name
        read reuse
        if [ "$reuse" == "y" ]; then
          echo -n "Please enter the name of the OPEN AI resource : "
          read OPENAI_RESOURCE_NAME
          echo -n "Please enter the name of the resource group where you have the OPEN AI resource "
          read OPENAI_RESOURCEg_NAME
          #TRYING TO GET THE ENDPOINT
          OPENAI_ENPOINT_URL=$(az cognitiveservices account show --name $OPENAI_RESOURCE_NAME --resource-group  $OPENAI_RESOURCEg_NAME | jq -r .properties.endpoint)
            #PRINT THE OPEN AI ENDPOINT URL
            echo "Open AI endpoint URL: $OPENAI_ENPOINT_URL"
            #IF THE ENDPOINT IS EMPTY THEN WE EXIT THE SCRIPT AND INFORM THE USER
            if [ -z "$OPENAI_ENPOINT_URL" ]; then
              echo "The Open AI resource name you entered does not exist in the resource group $RESOURCE_GROUP_NAME"
              echo "Please try again"
              exit 1
            fi
        else

             #create the open ai resource using azure cli
            OPENAI_RESOURCE_NAME="cop28-openai-$RANDOM_STRING"
            echo "Creating Open AI resource...$OPENAI_RESOURCE_NAME"
            #CLI SCRIPT TO CREATE THE OPEN AI RESOURCE
            az cognitiveservices account create --name $OPENAI_RESOURCE_NAME --resource-group $RESOURCE_GROUP_NAME --location eastus --kind OpenAI --sku s0 --subscription $SUBSCRIPTION_ID
            OPENAI_ENPOINT_URL=$(az cognitiveservices account show --name $OPENAI_RESOURCE_NAME --resource-group  $RESOURCE_GROUP_NAME | jq -r .properties.endpoint)
            #PRINT THE OPEN AI ENDPOINT URL
            echo "Open AI endpoint URL: $OPENAI_ENPOINT_URL"
            OPEN_AI_PRIMARY_KEY=$(az cognitiveservices account keys list --name $OPENAI_RESOURCE_NAME --resource-group $RESOURCE_GROUP_NAME | jq -r .key1)
            echo "Open AI primary key: $OPEN_AI_PRIMARY_KEY"
            #deploying adda002:
            #tell the user we are creating the embedded model
           

        fi
          echo "Creating embedded model using Open AI.text-embedding-ada-002"
          az cognitiveservices account deployment create --name $OPENAI_RESOURCE_NAME --resource-group  $RESOURCE_GROUP_NAME --deployment-name text-embedding-ada-002 --model-name text-embedding-ada-002 --model-version "2" --model-format OpenAI --sku-capacity "120" --sku-name "Standard"
          #create another model for chatgpt 35 turbo
          echo "Creating embedded model using Open AI.chat-gpt3-turbo"
          az cognitiveservices account deployment create --name $OPENAI_RESOURCE_NAME --resource-group  $RESOURCE_GROUP_NAME --deployment-name gpt-35-turbo --model-name gpt-35-turbo --model-version "0301" --model-format OpenAI --sku-capacity "240" --sku-name "Standard"
        
          echo "Creating Azure Content Safety resource..."
          #CLI SCRIPT TO CREATE THE AZURE CONTENT SAFETY RESOURCE
          az cognitiveservices account create --name "cop28-content-safety" --resource-group $RESOURCE_GROUP_NAME --location eastus --kind "ContentSafety" --sku s0 #--subscription $SUBSCRIPTION_ID
          #creating an azure ml workspace
          echo "Creating Azure ML workspace..."
          #CLI SCRIPT TO CREATE THE AZURE ML WORKSPACE
          ML_WORKSPACE_NAME="cop28-ml-workspace-$RANDOM_STRING"
          az ml workspace create --workspace-name $ML_WORKSPACE_NAME --resource-group $RESOURCE_GROUP_NAME --location eastus #--subscription $SUBSCRIPTION_ID
          #create an azure content safety resource
          
          #create the azure search service
          echo "Creating Azure Search service..."
          #CLI SCRIPT TO CREATE THE AZURE SEARCH SERVICE
          AZURE_SEARCH_NAME="cop28-search-service-$RANDOM_STRING"
          az search service create --name $AZURE_SEARCH_NAME --resource-group $RESOURCE_GROUP_NAME --location $LOCATION --sku Standard --partition-count 1 --replica-count 1
          #create the azure search index
          echo "Creating Azure Search index..."
          #CALLING THE AZURE SDK TO CREATE THE AZURE SEARCH INDEX
          #getting the adming key of the search service
          ADMIN_KEY=$(az search admin-key show --resource-group $RESOURCE_GROUP_NAME --service-name $AZURE_SEARCH_NAME --query primaryKey --output tsv)
          echo "admin key $ADMIN_KEY"

          url="https://$AZURE_SEARCH_NAME.search.windows.net/indexes?api-version=2023-07-01-Preview"
          accessToken=$(az account get-access-token --query accessToken --output tsv)
          ECHO "access token $accessToken "
          CONTENT_TYPE="application/json"          
          data='{
  "name": "microsoftdataindex",
  "defaultScoringProfile": null,
  "fields": [
    {
      "name": "content",
      "type": "Edm.String",
      "searchable": true,
      "filterable": false,
      "retrievable": true,
      "sortable": false,
      "facetable": false,
      "key": false,
      "indexAnalyzer": null,
      "searchAnalyzer": null,
      "analyzer": "standard",
      "dimensions": null,
      "vectorSearchConfiguration": null,
      "synonymMaps": []
    },
    {
      "name": "sourcepage",
      "type": "Edm.String",
      "searchable": false,
      "filterable": false,
      "retrievable": true,
      "sortable": false,
      "facetable": false,
      "key": false,
      "indexAnalyzer": null,
      "searchAnalyzer": null,
      "analyzer": null,
      "dimensions": null,
      "vectorSearchConfiguration": null,
      "synonymMaps": []
    },
    {
      "name": "sourcefile",
      "type": "Edm.String",
      "searchable": false,
      "filterable": false,
      "retrievable": true,
      "sortable": false,
      "facetable": false,
      "key": false,
      "indexAnalyzer": null,
      "searchAnalyzer": null,
      "analyzer": null,
      "normalizer": null,
      "dimensions": null,
      "vectorSearchConfiguration": null,
      "synonymMaps": []
    },
    {
      "name": "title",
      "type": "Edm.String",
      "searchable": true,
      "filterable": false,
      "retrievable": true,
      "sortable": false,
      "facetable": false,
      "key": false,
      "indexAnalyzer": null,
      "searchAnalyzer": null,
      "analyzer": null,
      "normalizer": null,
      "dimensions": null,
      "vectorSearchConfiguration": null,
      "synonymMaps": []
    },
    {
      "name": "meta_json_string",
      "type": "Edm.String",
      "searchable": false,
      "filterable": false,
      "retrievable": true,
      "sortable": false,
      "facetable": false,
      "key": false,
      "indexAnalyzer": null,
      "searchAnalyzer": null,
      "analyzer": null,
      "normalizer": null,
      "dimensions": null,
      "vectorSearchConfiguration": null,
      "synonymMaps": []
    },
    {
      "name": "content_vector_open_ai",
      "type": "Collection(Edm.Single)",
      "searchable": true,
      "filterable": false,
      "retrievable": true,
      "sortable": false,
      "facetable": false,
      "key": false,
      "indexAnalyzer": null,
      "searchAnalyzer": null,
      "analyzer": null,
      "normalizer": null,
      "dimensions": 1536,
      "vectorSearchConfiguration": "content_vector_open_ai_config",
      "synonymMaps": []
    },
    {
      "name": "id",
      "type": "Edm.String",
      "searchable": false,
      "filterable": false,
      "retrievable": true,
      "sortable": false,
      "facetable": false,
      "key": true,
      "indexAnalyzer": null,
      "searchAnalyzer": null,
      "analyzer": null,
      "normalizer": null,
      "dimensions": null,
      "vectorSearchConfiguration": null,
      "synonymMaps": []
    }
  ],
  "scoringProfiles": [],
  "corsOptions": null,
  "suggesters": [],
  "analyzers": [],
  "normalizers": [],
  "tokenizers": [],
  "tokenFilters": [],
  "charFilters": [],
  "encryptionKey": null,
  "similarity": {
    "@odata.type": "#Microsoft.Azure.Search.BM25Similarity",
    "k1": null,
    "b": null
  },
  "semantic": {
    "defaultConfiguration": null,
    "configurations": [
      {
        "name": "azureml-default",
        "prioritizedFields": {
          "titleField": {
            "fieldName": "title"
          },
          "prioritizedContentFields": [
            {
              "fieldName": "content"
            }
          ],
          "prioritizedKeywordsFields": []
        }
      }
    ]
  },
  "vectorSearch": {
    "algorithmConfigurations": [
      {
        "name": "content_vector_open_ai_config",
        "kind": "hnsw",
        "hnswParameters": {
          "metric": "cosine",
          "m": 4,
          "efConstruction": 400,
          "efSearch": 500
        },
        "exhaustiveKnnParameters": null
      }
    ]
  }
}'  # Your JSON payload

        echo "data $data"
        #-H "Authorization: Bearer $accessToken"
        curl -s -o response.txt -w "%{http_code}" -X POST  -H "api-key: $ADMIN_KEY" -H "Content-Type: $CONTENT_TYPE" -d "$data" $url > status.txt
        # Read the HTTP status code from the file
        HTTP_STATUS=$(cat status.txt)

        # Read the response body from the file
        RESPONSE=$(cat response.txt)

        # Print the HTTP status code and the response body
        echo "HTTP Status: $HTTP_STATUS"
        echo "Response: $RESPONSE"
        echo "url $url"
        #RESPONSE=$(curl -X POST -H "api-key: $API_KEY" -H "Content-Type: $contentType" -d "$data" $url)
        ECHO $RESPONSE
        echo "Azure Search index created."
      ;;
    2)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid option, please try again"
      ;;
  esac
done