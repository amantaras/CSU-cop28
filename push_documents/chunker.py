import concurrent.futures
import langchain
from langchain.embeddings import AzureOpenAIEmbeddings
import requests
from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient

from azure.search.documents.indexes.models import (
    ComplexField,
    SearchIndexerDataSourceConnection,
    SearchIndexerSkillset,
    SearchIndexer,
    SearchIndexerDataContainer,
    SearchFieldDataType,
)
import os
import dotenv
from langchain.document_loaders import TextLoader
from langchain.document_loaders import UnstructuredPDFLoader
from langchain.document_loaders import PyPDFLoader
from langchain.text_splitter import CharacterTextSplitter
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores.azuresearch import AzureSearch
import uuid
from tqdm import tqdm


# # Embed the chunks
def embed_chunk(chunk):
    # Use your pre-trained model to embed the chunks
    # Initialize OpenAI with your API key
    dotenv.load_dotenv()

    embeddings = AzureOpenAIEmbeddings(
        azure_deployment="text-embedding-ada-002",
        openai_api_version="2023-05-15",
    )

    # Use azure OpenAI's API to generate an embedding for the chunk
    response = embeddings.embed_query(chunk)
    # Extract the embedding from the response
    return response


# # Create the document structure for Azure Search Index


def show_progress_bar(bar_length, completed, total):
    bar_length_unit_value = total / bar_length
    completed_bar_part = math.ceil(completed / bar_length_unit_value)
    progress = "*" * completed_bar_part
    remaining = " " * (bar_length - completed_bar_part)
    percent_done = "%.2f" % ((completed / total) * 100)
    print(f"[{progress}{remaining}] {percent_done}%")


def create_document_structure(chunks):
    documents = []
    loop_iterations = len(chunks)
    for chunk in chunks:
        document = {
            "content": chunk.page_content,
            "sourcepage": "sourcepage",
            "sourcefile": "sourcefile",
            "title": "title",
            "meta_json_string": "meta_json_string",
            "content_vector_open_ai": embed_chunk(chunk.page_content),
            "id": str(uuid.uuid4()),
        }
        # show_progress_bar(bar_length=50, completed=idx + 1, total=loop_iterations)

        # documents.append(document)
        insert_into_azure_search_index(document)
    return documents


# # Insert the document into the Azure Search Index
def insert_into_azure_search_index(document):
    endpoint = "https://cop28-search-service-of2re.search.windows.net"
    index_name = "microsoftdataindex"
    api_key = "GXuf0X7E3ZfBiUamS7KKmYihKpcj96nbWbrz9V94JEAzSeB3A1WY"

    credential = AzureKeyCredential(api_key)
    client = SearchClient(
        endpoint=endpoint, index_name=index_name, credential=credential
    )
  
    results = client.upload_documents(documents=[document])


def process_document(directory, filename):
    if filename.endswith(".pdf"):
        document = os.path.join(directory, filename)
        loader = PyPDFLoader(document)
        documents = loader.load()
        text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=0)
        docs = text_splitter.split_documents(documents)
        return create_document_structure(docs)


# Main function
def main():
    os.environ["OPENAI_API_TYPE"] = "azure"
    os.environ["AZURE_OPENAI_API_BASE"] = "https://eastus.api.cognitive.microsoft.com"
    os.environ["AZURE_OPENAI_API_KEY"] = "eaa8ee2f84c945a1bf3650a36edf02ea"
    os.environ["AZURE_OPENAI_ENDPOINT"] = "https://eastus.api.cognitive.microsoft.com/"
    os.environ["AZURE_OPENAI_API_VERSION"] = "2023-05-15"
    vector_store_address: str = "https://cop28-search-service-of2re.search.windows.net"
    vector_store_password: str = "GXuf0X7E3ZfBiUamS7KKmYihKpcj96nbWbrz9V94JEAzSeB3A1WY"
    index_name = "microsoftdataindex"
    model: str = "text-embedding-ada-002"
    dotenv.load_dotenv()
    embeddings: AzureOpenAIEmbeddings = AzureOpenAIEmbeddings(
        deployment=model, chunk_size=1
    )

    vector_store: AzureSearch = AzureSearch(
        azure_search_endpoint=vector_store_address,
        azure_search_key=vector_store_password,
        index_name=index_name,
        embedding_function=embeddings.embed_query,
    )

    # document = "C:/Users/amantara/OneDrive - Microsoft/cop28/data/msdata/Microsoft Carbon Removal FY23 Lessons Learned.pdf"

    directory = "C:/Users/amantara/OneDrive - Microsoft/cop28/data/msdata/"
    pdf_files = [f for f in os.listdir(directory) if f.endswith(".pdf")]

    # Muestra el número total de documentos a procesar
    print(f"Total # docs to upload: {len(pdf_files)}")
    with concurrent.futures.ProcessPoolExecutor() as executor:
        futures = {
            executor.submit(process_document, directory, filename)
            for filename in os.listdir(directory)
        }
        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            index_generated = future.result()
            print(f"Processed document {i} of {len(pdf_files)}")

    print("process completed!")


if __name__ == "__main__":
    main()
