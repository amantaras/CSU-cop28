from typing import List
from promptflow import tool
from promptflow_vectordb.core.contracts import SearchResultEntity
import json

@tool
def generate_prompt_context(search_result: List[dict]) -> str:
    retrieved_docs = []
    for item in search_result:
        entity = SearchResultEntity.from_dict(item)
        print('this is the original entity')
        original_entity = json.dumps(entity.original_entity)
        print(original_entity)
        original_entity_dict = json.loads(original_entity)
        content = original_entity_dict["content"]
        print ("this is the content")
        print (content)

        retrieved_docs.append(content)
       
    doc_string = "\n\n".join([doc for doc in retrieved_docs])
    return doc_string
