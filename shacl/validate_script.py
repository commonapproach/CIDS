#
# SHACL Validator Script
#
# This script validates a JSON-LD data file against a SHACL shapes file.
# It requires the paths to the data file and the SHACL file to be provided
# as command-line arguments.
#
# Optional setup commands in local application folder
# python3 -m venv venv
# source venv/bin/activate
# pip install pyshacl
# 
# Example run command from local folder
# python validate_script.py CIDSBasicandSFF.json shacl.ttl
#
# Arguments:
#   data_file_path: The path to the JSON-LD file to be validated.
#   shacl_file_path: The path to the SHACL Turtle (.ttl) file to use for validation.
#

import rdflib
from pyshacl import validate
import argparse
import os
from datetime import datetime
from collections import Counter
import re

def validate_data(data_file, shacl_file, ont_sources, log_file):
    """
    Validates an RDF data file against a SHACL shapes file, including ontologies.

    Args:
        data_file (str): Path to the JSON-LD data file to validate.
        shacl_file (str): Path to the SHACL Turtle file.
        ont_sources (list): A list of paths or URLs to ontology files.
        log_file (str): Path to the output log file.
    """
    # --- 1. Load all graphs ---
    try:
        print(f"Loading data graph from: {data_file}")
        data_graph = rdflib.Graph().parse(data_file, format='json-ld')

        print(f"Loading SHACL graph from: {shacl_file}")
        shacl_graph = rdflib.Graph().parse(shacl_file, format='turtle')

        # Load and combine all ontology graphs from local files or URLs
        ont_graph = rdflib.Graph()
        for source in ont_sources:
            print(f"Loading ontology from: {source}")
            ont_graph.parse(source, format='xml')

        print(f"\nData graph has {len(data_graph)} triples.")
        print(f"SHACL graph has {len(shacl_graph)} triples.")
        print(f"Ontology graph has {len(ont_graph)} triples.")

    except FileNotFoundError as e:
        print(f"\n--- ERROR ---")
        print(f"File not found: {e}. Please check your file paths.")
        return
    except Exception as e:
        print(f"\n--- ERROR ---")
        print(f"An error occurred while parsing files or URLs: {e}")
        return

    # --- 2. Perform validation ---
    try:
        print("\nStarting validation...")
        conforms, results_graph, results_text = validate(
            data_graph,
            shacl_graph=shacl_graph,
            ont_graph=ont_graph,
            inference='rdfs',  # Enable RDFS reasoning
            meta_shacl=False,
            advanced=True,
            js=False,
            debug=False
        )
    except Exception as e:
        print(f"\n--- ERROR ---")
        print(f"An error occurred during validation: {e}")
        return

    # --- 3. Write results to log file ---
    
    # First, generate a summary of violations if any
    violation_summary = {}
    if not conforms:
        # Collect and generalize messages for the summary
        messages = []
        for r in results_graph.subjects(rdf.type, sh.ValidationResult):
            message = results_graph.value(r, sh.resultMessage)
            if message:
                message_str = str(message)
                # Generalize MinCount and MaxCount violation messages for summary
                if message_str.startswith("Less than") or message_str.startswith("More than"):
                    # Use regex to extract the generic part of the message, e.g., "Less than 1 values"
                    match = re.match(r"^(Less than \d+ values|More than \d+ values)", message_str)
                    if match:
                        messages.append(match.group(1))
                    else:
                        messages.append(message_str) # Fallback
                else:
                    messages.append(message_str)
        
        violation_summary = Counter(messages)

    with open(log_file, 'w') as f:
        f.write("--- SHACL Validation Report ---\n")
        f.write(f"Validated: {os.path.basename(data_file)}\n")
        f.write(f"On: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"Data conforms to shapes: {conforms}\n")

        if not conforms:
            f.write("\n--- Violation Summary ---\n")
            if violation_summary:
                for msg, count in violation_summary.items():
                    f.write(f"- {msg} ({count})\n")
            else:
                f.write("No violations found.\n")

        f.write("\n--- Details ---\n")
        f.write(results_text)
        
        if not conforms:
            f.write("\n--- Individual Violations ---\n")
            for r in results_graph.subjects(rdf.type, sh.ValidationResult):
                message = results_graph.value(r, sh.resultMessage)
                focus_node = results_graph.value(r, sh.focusNode)
                severity = results_graph.value(r, sh.resultSeverity)
                source_shape = results_graph.value(r, sh.sourceShape)
                
                f.write(f"\n- Violation/Warning:\n")
                f.write(f"  Severity: {str(severity).split('#')[-1]}\n")
                f.write(f"  Focus Node: {focus_node}\n")
                f.write(f"  Message: {message}\n")
                f.write(f"  Source Shape: {source_shape}\n")

    print(f"\nValidation complete. Report saved to '{log_file}'")
    if not conforms:
        print("Validation failed. Check the log file for details.")
    else:
        print("Validation successful!")

if __name__ == '__main__':
    # --- Setup command-line argument parser ---
    parser = argparse.ArgumentParser(description='Validate a JSON-LD file against a SHACL shapes file.')
    parser.add_argument('data_file', help='The path to the JSON-LD file to be validated.')
    parser.add_argument('shacl_file', help='The path to the SHACL Turtle (.ttl) file.')
    args = parser.parse_args()

    # --- Define ontology sources (these can be URLs or local files) ---
    ontology_sources = [
        'https://ontology.commonapproach.org/cids.owl',
        'https://ontology.commonapproach.org/sff-1.0.owl'
    ]
    
    # --- Generate dynamic log file name ---
    base_name = os.path.basename(args.data_file)
    file_name_without_ext = os.path.splitext(base_name)[0]
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    output_log_file = f"validation_log_{file_name_without_ext}_{timestamp}.txt"

    # --- Define RDF and SHACL namespaces for results processing ---
    rdf = rdflib.namespace.RDF
    sh = rdflib.namespace.SH

    # --- Run the validation ---
    validate_data(args.data_file, args.shacl_file, ontology_sources, output_log_file)
