# main.py
import json
import requests
import PyPDF2
import asyncio
import aiohttp
from io import BytesIO
from bs4 import BeautifulSoup
from rdflib import Graph, Namespace
from rdflib.namespace import RDF, RDFS

# Define the CIDS namespace
CIDS = Namespace("https://ontology.commonapproach.org/cids#")
ORG = Namespace("http://ontology.eil.utoronto.ca/tove/organization#")
SDG = Namespace("https://codelist.commonapproach.org/SDGImpacts/")

def load_cids_ontology(ontology_urls):
    """
    Loads the CIDS ontology from one or more URLs into an RDFLib graph.

    Args:
        ontology_urls (list): A list of URLs pointing to the ontology files.

    Returns:
        rdflib.Graph: A graph containing the CIDS ontology, or an empty graph if loading fails.
    """
    g = Graph()
    print("Loading CIDS ontology from sources...")
    for url in ontology_urls:
        try:
            # rdflib's parse function can handle URLs directly and auto-detect format
            print(f"--> Fetching from {url}")
            g.parse(url, format='turtle') # Explicitly setting format for .ttl file
        except Exception as e:
            print(f"An error occurred while parsing the ontology from {url}: {e}")
    
    if len(g) > 0:
        print("CIDS ontology loaded successfully.")
    else:
        print("Warning: Failed to load any ontology data. The graph is empty.")
    
    return g

def get_text_from_pdf_url(url):
    """
    Downloads a PDF from a URL and extracts its text content.
    Note: You will need to install the 'requests' and 'PyPDF2' libraries.
    Run: pip install requests PyPDF2

    Args:
        url (str): The URL of the PDF file.

    Returns:
        str: The extracted text from the PDF, or None if an error occurs.
    """
    print(f"Fetching report from {url}...")
    try:
        # Use a User-Agent to mimic a browser and avoid potential blocking
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'}
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # Raise an exception for bad status codes

        # Use BytesIO to treat the downloaded content as a file-like object
        pdf_file = BytesIO(response.content)
        
        # Read the PDF
        pdf_reader = PyPDF2.PdfReader(pdf_file)
        text = ""
        for page in pdf_reader.pages:
            text += page.extract_text() or ""
        
        print("Successfully extracted text from PDF.")
        return text
    except requests.exceptions.RequestException as e:
        print(f"Error downloading the file: {e}")
        return None
    except PyPDF2.errors.PdfReadError:
        print("Error: Could not read the PDF file. It may be corrupted or not a valid PDF.")
        return None
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return None


async def analyze_nonprofit_data(report_text, cids_graph):
    """
    Analyzes nonprofit report text using the Gemini API to extract entities
    and relationships, formatting them according to a CIDS-aligned JSON schema.

    Args:
        report_text (str): The text content of the nonprofit's report.
        cids_graph (rdflib.Graph): The graph containing the CIDS ontology (for context).

    Returns:
        list: A list of dictionaries representing the extracted entities, or None if an error occurs.
    """
    print("Analyzing nonprofit data with the Gemini API...")

    # --- IMPORTANT ---
    # Replace "YOUR_API_KEY_HERE" with your actual Gemini API key from Google AI Studio.
    api_key = "AIzaSyARHjICoRxIHuwu22UySls4OrkCwqf7c9c"
    
    if api_key == "YOUR_API_KEY_HERE":
        print("Error: Please replace 'YOUR_API_KEY_HERE' with your actual Gemini API key.")
        return None

    api_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key={api_key}"

    # Define the flattened JSON schema with simplified property names that align with the CIDS context file.
    json_schema = {
        "type": "ARRAY",
        "description": "A flat list of all extracted entities, linked by unique @id fields, using simplified property names.",
        "items": {
            "type": "OBJECT",
            "properties": {
                "@id": {"type": "STRING", "description": "A unique, document-local identifier, starting with '#' (e.g., '#org-1')."},
                "@type": {
                    "type": "STRING", 
                    "description": "The CIDS class type for the entity, with a prefix (e.g., 'cids:IndicatorReport').",
                    "pattern": "^[a-zA-Z]+:[A-Z][a-zA-Z]+$"
                },
                "hasName": {"type": "STRING"},
                "hasDescription": {"type": "STRING"},
                # --- Relational Properties ---
                "hasOutcome": {
                    "type": "ARRAY", "items": {"type": "STRING", "description": "An array of @id strings referencing Outcome objects."}
                },
                "hasIndicator": {
                    "type": "ARRAY", "items": {"type": "STRING", "description": "An array of @id strings referencing Indicator objects."}
                },
                "hasIndicatorReport": {
                    "type": "ARRAY", "items": {"type": "STRING", "description": "An array of @id strings referencing IndicatorReport objects."}
                },
                "forTheme": {
                    "type": "ARRAY", "items": {"type": "STRING", "description": "An array of @id strings referencing Theme objects."}
                },
                 "forOutcome": {
                    "type": "ARRAY", "items": {"type": "STRING", "description": "An array of @id strings referencing Outcome objects."}
                },
                # --- Literal Properties for specific types ---
                "startedAtTime": {"type": "STRING", "format": "date-time"},
                "endedAtTime": {"type": "STRING", "format": "date-time"},
                "hasCode": {"type": "STRING", "description": "e.g., 'sdg:SDG-1.1'"}
            },
            "required": ["@id", "@type", "hasName"]
        }
    }


    # Construct the prompt for the language model.
    prompt = f"""
    Analyze the following nonprofit annual report text. Your task is to extract key entities based on the CIDS ontology and structure them as a flattened graph with ID-based links.

    Instructions:
    1.  Identify all relevant entities: the main Organization, all of its Outcomes, all Indicators, any IndicatorReports, and any thematic areas (including UN SDGs).
    2.  Create a flat JSON array containing an object for EACH entity.
    3.  For every object, you MUST assign a unique, document-local `@id` starting with '#'. For example: `"#org-wikimedia"`.
    4.  For the `@type` property, you MUST use the full prefixed name, such as `cids:Organization` or `cids:IndicatorReport`.
    5.  For all other properties, you MUST use the simplified, unprefixed names as defined in the CIDS context (e.g., use `hasOutcome` instead of `cids:hasOutcome`, `hasName` instead of `org:hasName`).
    6.  Create relationships by referencing `@id`s. For example, an Outcome object's `hasIndicator` property should contain an array of `@id` strings that point to the relevant Indicator objects.

    Return a single JSON array of these objects that conforms to the provided schema.

    Report Text:
    ---
    {report_text[:8000]} 
    ---
    """
    
    # We truncate the report text to avoid exceeding API limits.

    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": json_schema
        }
    }

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(api_url, json=payload) as response:
                response.raise_for_status()
                result = await response.json()
                
                # Extract the JSON string from the response
                content_part = result.get('candidates', [{}])[0].get('content', {}).get('parts', [{}])[0]
                json_string = content_part.get('text', '[]')
                
                print("Successfully received and parsed structured data from the API.")
                return json.loads(json_string)

    except aiohttp.ClientError as e:
        print(f"An error occurred during the API request: {e}")
        return None
    except (json.JSONDecodeError, IndexError, KeyError) as e:
        print(f"Error parsing the API response: {e}")
        print("Raw response:", await response.text())
        return None


def create_jsonld_knowledge_graph(extracted_data):
    """
    Creates a self-contained JSON-LD knowledge graph from the extracted data
    by fetching and embedding the official CIDS context.

    Args:
        extracted_data (list): A list of dictionaries representing the flattened
                               graph entities.

    Returns:
        dict: A dictionary representing the JSON-LD knowledge graph.
    """
    # Fetch the external CIDS context
    context_url = "https://ontology.commonapproach.org/contexts/cidsContext.jsonld"
    print(f"Fetching context from {context_url}...")
    try:
        response = requests.get(context_url)
        response.raise_for_status()
        # The context from the URL is nested under a "@context" key
        cids_context = response.json().get("@context", {})
    except requests.exceptions.RequestException as e:
        print(f"Error fetching CIDS context: {e}. Using a fallback.")
        # Fallback to a minimal context if fetching fails
        cids_context = {
            "cids": str(CIDS),
            "org": str(ORG),
            "sdg": str(SDG),
            "rdf": str(RDF),
            "rdfs": str(RDFS),
            "prov": "http://www.w3.org/ns/prov#"
        }
    except json.JSONDecodeError:
        print("Error decoding CIDS context JSON. Using a fallback.")
        cids_context = {}


    # Add the @base URI to the fetched context for local ID resolution
    cids_context["@base"] = "https://www.example.org/"

    jsonld_graph = {
        "@context": cids_context,
        "@graph": extracted_data
    }
    print("JSON-LD knowledge graph created with embedded context.")
    return jsonld_graph

def save_jsonld_to_file(jsonld_data, output_file):
    """
    Saves the JSON-LD data to a file.

    Args:
        jsonld_data (dict): The JSON-LD data to save.
        output_file (str): The path to the output file.
    """
    try:
        with open(output_file, 'w') as f:
            json.dump(jsonld_data, f, indent=2)
        print(f"Knowledge graph saved to '{output_file}'.")
    except IOError as e:
        print(f"Error saving file: {e}")


async def main():
    """
    Main function to run the entire data processing pipeline.
    """
    # 1. Load the CIDS ontology and SDG codelist from URLs
    cids_ontology_urls = [
        "https://ontology.commonapproach.org/cids.ttl",
        "https://codelist.commonapproach.org/SDGImpacts/SDGImpacts.ttl"
    ]
    cids_graph = load_cids_ontology(cids_ontology_urls)

    # Proceed only if the ontology was loaded successfully
    if cids_graph and len(cids_graph) > 0:
        # 2. Specify the URL for the nonprofit report and extract text
        report_url = "https://fsgv.ca/wp-content/uploads/2024/09/Digital-Family-Services-of-Greater-Vancouver-Annual-Report-2024.pdf"
        nonprofit_report_text = get_text_from_pdf_url(report_url)

        # Proceed only if text was successfully extracted
        if nonprofit_report_text:
            extracted_entities = await analyze_nonprofit_data(nonprofit_report_text, cids_graph)

            if extracted_entities:
                # 3. Create the JSON-LD knowledge graph
                knowledge_graph = create_jsonld_knowledge_graph(extracted_entities)

                # 4. Save the knowledge graph to a file
                output_filename = 'knowledge_graph.jsonld'
                save_jsonld_to_file(knowledge_graph, output_filename)
            else:
                print("Analysis did not return any entities. Halting process.")
        else:
            print("Could not process the report due to an error in text extraction.")
    else:
        print("Could not run analysis because the CIDS ontology failed to load.")

if __name__ == "__main__":
    # Run the main asynchronous function
    asyncio.run(main())

