#
# RDF Format Converter and Verifier
#
# Description:
# This script converts RDF files from one format to another using the rdflib library.
# It also verifies that the conversion was successful by checking if the original
# and converted RDF graphs are isomorphic (structurally equivalent).
#
# Usage:
# python convert_rdf.py <input_file_path> <output_file_path>
#
# Example Commands:
#
# 1. To convert an OWL (RDF/XML) file to Turtle (.ttl):
#    python convert_rdf.py cids.owl.txt cids.ttl
#
# 2. To convert a Turtle (.ttl) file to OWL (RDF/XML):
#    python convert_rdf.py sff.ttl sff.owl.xml
#

import sys
import os
from rdflib import Graph
from rdflib.compare import isomorphic

def convert_and_verify(input_file, output_file):
    """
    Parses an RDF file, converts it to a specified format, and verifies
    that the original and converted graphs are isomorphic.

    Args:
        input_file (str): The path to the source RDF file.
        output_file (str): The path for the converted RDF file.
    """
    if not os.path.exists(input_file):
        print(f"Error: Input file not found at '{input_file}'")
        return

    # --- 1. Conversion ---
    print(f"Attempting to convert '{input_file}' to '{output_file}'...")

    # Create a graph and parse the input file
    original_graph = Graph()
    try:
        print(f"-> Parsing '{input_file}'...")
        original_graph.parse(input_file)
        print(f"-> Successfully parsed. Found {len(original_graph)} triples.")
    except Exception as e:
        print(f"Error: Failed to parse input file. \n{e}")
        return

    # Serialize the graph to the specified output format
    try:
        print(f"-> Serializing to '{output_file}'...")
        original_graph.serialize(destination=output_file)
        print("-> Conversion successful.")
    except Exception as e:
        print(f"Error: Failed to serialize to output file. \n{e}")
        return

    # --- 2. Verification ---
    print("\nVerifying conversion...")

    # Create a new graph from the converted file
    converted_graph = Graph()
    try:
        print(f"-> Parsing newly created file '{output_file}' for verification...")
        converted_graph.parse(output_file)
        print(f"-> Successfully parsed. Found {len(converted_graph)} triples.")
    except Exception as e:
        print(f"Error: Failed to parse the new output file for verification. \n{e}")
        return

    # Compare the two graphs for isomorphism
    try:
        if isomorphic(original_graph, converted_graph):
            print("\n✅ Success: Verification complete. The graphs are isomorphic.")
        else:
            print("\n❌ Error: Verification failed. The graphs are NOT isomorphic.")
    except Exception as e:
        print(f"\nAn unexpected error occurred during graph comparison. \n{e}")


if __name__ == "__main__":
    # Check for the correct number of command-line arguments
    if len(sys.argv) != 3:
        print("Usage: python convert_rdf.py <input_file_path> <output_file_path>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    convert_and_verify(input_path, output_path)