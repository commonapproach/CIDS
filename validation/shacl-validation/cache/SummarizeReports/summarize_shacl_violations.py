#!/usr/bin/env python3
"""
Summarize SHACL validation violations from Apache Jena validation reports.
Groups violations by resultPath, resultMessage, and node type.
Outputs a plain text summary report.
Usage: python summarize_shacl_violations.py <validation_report.ttl> [output.txt]
Example: python summarize_shacl_violations.py CRGbasic_validation/report--CRGbasic.ttl CRGbasic_validation/CRGbasic_summary.txt
"""

import sys
import warnings
import os
import json
from collections import defaultdict
from rdflib import Graph, Namespace
from rdflib.namespace import RDF
import re

# Define SHACL namespace
SH = Namespace("http://www.w3.org/ns/shacl#")

def extract_node_type(source_shape):
    """
    Extract node type from sourceShape.
    Pattern: csh:NodeType_property_PropertyShape -> NodeType
    Also handles full URIs.
    """
    if not source_shape:
        return "Unknown"
    
    # Convert to string
    shape_str = str(source_shape)
    
    # Pattern 1: prefix:NodeType_property_PropertyShape (e.g., csh:IndicatorReport_endedAtTime_PropertyShape)
    # Extract the part between the colon/prefix and the first underscore
    match = re.search(r':([A-Za-z][A-Za-z0-9]*)_', shape_str)
    if match:
        return match.group(1)
    
    # Pattern 2: Full URI with # (e.g., https://example.org#NodeType_property_PropertyShape)
    if '#' in shape_str:
        fragment = shape_str.split('#')[-1]
        parts = fragment.split('_')
        if parts:
            return parts[0]
    
    # Pattern 3: Full URI with / (e.g., https://example.org/NodeType_property_PropertyShape)
    if '/' in shape_str:
        parts = shape_str.split('/')
        last_part = parts[-1] if parts else ""
        node_part = last_part.split('_')[0]
        if node_part:
            return node_part
    
    return "Unknown"

def extract_property_name(property_uri):
    """
    Extract the local name from a property URI.
    Handles full URIs, prefixed names, and local names.
    
    Examples:
    - "https://ontology.commonapproach.org/cids#forOrganization" -> "forOrganization"
    - "http://www.w3.org/ns/prov#endedAtTime" -> "endedAtTime"
    - "cids:forOrganization" -> "forOrganization"
    - "forOrganization" -> "forOrganization"
    """
    if not property_uri:
        return "Unknown"
    
    prop_str = str(property_uri)
    
    # Handle prefixed names (e.g., "cids:forOrganization")
    if ':' in prop_str and not prop_str.startswith('http'):
        return prop_str.split(':')[-1]
    
    # Handle full URIs with # fragment (e.g., "https://example.org/ns#propertyName")
    if '#' in prop_str:
        return prop_str.split('#')[-1]
    
    # Handle full URIs with / path (e.g., "http://example.org/ns/propertyName")
    if '/' in prop_str and prop_str.startswith('http'):
        return prop_str.split('/')[-1]
    
    # Already a local name
    return prop_str

def normalize_error_message(result_message):
    """
    Normalize error message by truncating the actual value part.
    Groups violations with the same constraint type and expected value together.
    
    Examples:
    - "DatatypeConstraint[xsd:dateTime]: Expected xsd:dateTime : Actual xsd:string : Node \"2025-12-31T13:50:00-05:00\""
      -> "DatatypeConstraint[xsd:dateTime]: Expected xsd:dateTime"
    - "ClassConstraint[...]: Expected class :..." -> "ClassConstraint[...]: Expected class"
    - "minCount[1]: Invalid cardinality: expected min 1: Got count = 0" -> "minCount[1]: Invalid cardinality: expected min 1"
    """
    if not result_message:
        return "Unknown"
    
    msg_str = str(result_message)
    
    # DatatypeConstraint: truncate after "Expected <type>"
    if msg_str.startswith("DatatypeConstraint"):
        match = re.search(r'(DatatypeConstraint\[[^\]]+\]:\s*Expected\s+[^:]+)', msg_str)
        if match:
            return match.group(1)
    
    # ClassConstraint: truncate after the expected class URI (before "for")
    elif msg_str.startswith("ClassConstraint"):
        # Pattern: "ClassConstraint[...]: Expected class :<URI> for <actual_value>"
        # We want to keep up to the expected URI, removing " for <actual_value>"
        if ' for ' in msg_str:
            return msg_str.split(' for ')[0]
        # Fallback if no "for" pattern
        match = re.search(r'(ClassConstraint\[[^\]]+\]:\s*Expected\s+class\s*:[^:]+)', msg_str)
        if match:
            return match.group(1)
    
    # minCount/maxCount: truncate after "expected min/max <number>"
    elif msg_str.startswith("minCount") or msg_str.startswith("maxCount"):
        match = re.search(r'((?:min|max)Count\[\d+\]:\s*Invalid\s+cardinality:\s*expected\s+(?:min|max)\s+\d+)', msg_str)
        if match:
            return match.group(1)
    
    # NodeKindConstraint: truncate after "Expected"
    elif msg_str.startswith("NodeKindConstraint"):
        match = re.search(r'(NodeKindConstraint[^:]+:\s*Expected[^:]+)', msg_str)
        if match:
            return match.group(1)
    
    # For other types, try to truncate at common patterns
    # Look for patterns like ": Actual" or ": Got" or ": Node"
    for pattern in [': Actual', ': Got', ': Node']:
        if pattern in msg_str:
            return msg_str.split(pattern)[0]
    
    # If no pattern matches, return the full message
    return msg_str

def extract_constraint_type(result_message):
    """
    Extract constraint type from resultMessage.
    Examples:
    - "DatatypeConstraint[xsd:dateTime]: ..." -> "DatatypeConstraint"
    - "ClassConstraint[...]: ..." -> "ClassConstraint"
    - "minCount[1]: ..." -> "MinCountConstraint"
    """
    if not result_message:
        return "Unknown"
    
    msg_str = str(result_message)
    
    # Check for explicit constraint types
    if msg_str.startswith("DatatypeConstraint"):
        return "DatatypeConstraint"
    elif msg_str.startswith("ClassConstraint"):
        return "ClassConstraint"
    elif msg_str.startswith("minCount"):
        return "MinCountConstraint"
    elif msg_str.startswith("maxCount"):
        return "MaxCountConstraint"
    elif msg_str.startswith("NodeKindConstraint"):
        return "NodeKindConstraint"
    elif msg_str.startswith("InConstraint"):
        return "InConstraint"
    elif msg_str.startswith("HasValueConstraint"):
        return "HasValueConstraint"
    
    # Try to extract from sourceConstraintComponent if available
    return "Other"

def normalize_value(value):
    """
    Normalize violation values by replacing file:// URIs with empty string indicator.
    When Apache Jena encounters empty strings in JSON-LD, it may resolve them to the
    document base URI (file:// path). This function detects and replaces such values.
    
    Args:
        value: The value string from the validation report
        
    Returns:
        Normalized value string, or None if value is None
    """
    if value is None:
        return None
    
    value_str = str(value)
    
    # Check if the value is a file:// URI (indicating an empty string was resolved to base URI)
    if value_str.startswith("file:///"):
        return 'empty string ("")'
    
    return value_str

def extract_severity_name(severity_uri):
    """
    Extract a clean severity name from a severity URI.
    Examples:
    - "http://www.w3.org/ns/shacl#Violation" -> "Violation"
    - "http://www.w3.org/ns/shacl#Warning" -> "Warning"
    - "http://www.w3.org/ns/shacl#Info" -> "Info"
    
    Args:
        severity_uri: The severity URI string
        
    Returns:
        Clean severity name, or the original string if not a recognized pattern
    """
    if not severity_uri:
        return None
    
    uri_str = str(severity_uri)
    
    # Extract the local name from SHACL namespace URIs
    if 'shacl#Violation' in uri_str or uri_str.endswith('#Violation'):
        return "Violation"
    elif 'shacl#Warning' in uri_str or uri_str.endswith('#Warning'):
        return "Warning"
    elif 'shacl#Info' in uri_str or uri_str.endswith('#Info'):
        return "Info"
    
    # Try to extract the fragment/name part
    if '#' in uri_str:
        return uri_str.split('#')[-1]
    elif '/' in uri_str:
        return uri_str.split('/')[-1]
    
    return uri_str

def is_codelist_node(focus_node_uri):
    """
    Check if a focus node URI belongs to an imported codelist.
    Codelists are typically identified by their domain patterns.
    
    Args:
        focus_node_uri: The focus node URI string
        
    Returns:
        True if the node belongs to a codelist, False otherwise
    """
    if not focus_node_uri:
        return False
    
    uri_str = str(focus_node_uri)
    
    # Common codelist domain patterns
    codelist_patterns = [
        'codelist.commonapproach.org',
        'metadata.un.org',  # SDG metadata
        # Add other codelist domains as needed
    ]
    
    for pattern in codelist_patterns:
        if pattern in uri_str:
            return True
    
    return False

def parse_validation_report(file_path):
    """Parse the SHACL validation report and extract all violations."""
    g = Graph()
    
    # Suppress rdflib warnings and error messages about invalid literals
    # These are printed to stderr but don't stop parsing
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore")
        # Redirect stderr temporarily to suppress rdflib's error tracebacks
        # Save original stderr
        original_stderr = sys.stderr
        try:
            # Redirect stderr to devnull to suppress rdflib's ValueError tracebacks
            with open(os.devnull, 'w') as devnull:
                sys.stderr = devnull
                try:
                    g.parse(file_path, format="turtle")
                except Exception as e:
                    # Restore stderr before printing our error
                    sys.stderr = original_stderr
                    print(f"Warning: Error parsing RDF file: {e}", file=sys.stderr)
                    print("Attempting to continue with partial parse...", file=sys.stderr)
                    # Try to continue - rdflib may have parsed some triples before the error
                finally:
                    # Always restore stderr
                    sys.stderr = original_stderr
        except Exception as e:
            # Restore stderr in case of outer exception
            sys.stderr = original_stderr
            print(f"Warning: Error parsing RDF file: {e}", file=sys.stderr)
    
    violations = []
    
    # Find all ValidationResult instances
    try:
        for result in g.subjects(RDF.type, SH.ValidationResult):
            violation = {}
            
            try:
                # Extract focusNode
                focus_nodes = list(g.objects(result, SH.focusNode))
                violation['focusNode'] = str(focus_nodes[0]) if focus_nodes else None
            except Exception as e:
                violation['focusNode'] = None
                print(f"Warning: Error extracting focusNode: {e}", file=sys.stderr)
            
            try:
                # Extract resultMessage
                messages = list(g.objects(result, SH.resultMessage))
                violation['resultMessage'] = str(messages[0]) if messages else None
            except Exception as e:
                violation['resultMessage'] = None
                print(f"Warning: Error extracting resultMessage: {e}", file=sys.stderr)
            
            try:
                # Extract resultPath
                paths = list(g.objects(result, SH.resultPath))
                violation['resultPath'] = str(paths[0]) if paths else None
            except Exception as e:
                violation['resultPath'] = None
                print(f"Warning: Error extracting resultPath: {e}", file=sys.stderr)
            
            try:
                # Extract sourceShape
                shapes = list(g.objects(result, SH.sourceShape))
                violation['sourceShape'] = str(shapes[0]) if shapes else None
            except Exception as e:
                violation['sourceShape'] = None
                print(f"Warning: Error extracting sourceShape: {e}", file=sys.stderr)
            
            try:
                # Extract sourceConstraintComponent
                components = list(g.objects(result, SH.sourceConstraintComponent))
                violation['constraintComponent'] = str(components[0]) if components else None
            except Exception as e:
                violation['constraintComponent'] = None
                print(f"Warning: Error extracting constraintComponent: {e}", file=sys.stderr)
            
            try:
                # Extract resultSeverity
                severities = list(g.objects(result, SH.resultSeverity))
                violation['severity'] = str(severities[0]) if severities else None
            except Exception as e:
                violation['severity'] = None
                print(f"Warning: Error extracting severity: {e}", file=sys.stderr)
            
            try:
                # Extract value (if present) - this is where invalid literals often cause issues
                values = list(g.objects(result, SH.value))
                if values:
                    # Try to convert to string, but handle errors gracefully
                    try:
                        violation['value'] = str(values[0])
                    except (ValueError, TypeError) as e:
                        # Invalid literal (e.g., empty string with xsd:dateTime type)
                        violation['value'] = f"<invalid_literal: {type(values[0]).__name__}>"
                else:
                    violation['value'] = None
            except Exception as e:
                violation['value'] = None
                print(f"Warning: Error extracting value: {e}", file=sys.stderr)
            
            violations.append(violation)
    except Exception as e:
        print(f"Error: Failed to extract violations from validation report: {e}", file=sys.stderr)
        print("Returning empty violations list.", file=sys.stderr)
    
    return violations

def generate_summary(violations, output_file, include_codelist_violations=False, command=None, node_type_counts=None):
    """Generate and write the summary report.
    
    Args:
        violations: List of violation dictionaries
        output_file: Path to output file
        include_codelist_violations: If True, include violations from codelists; if False, exclude them (default)
        command: Original command line string (optional)
        node_type_counts: Dictionary of node type counts from source data file (optional)
    """
    
    # Filter out violations that belong to imported codelists (unless flag is set)
    filtered_violations = []
    codelist_violations_count = 0
    
    for v in violations:
        focus_node = v.get('focusNode')
        is_codelist = is_codelist_node(focus_node)
        
        if is_codelist:
            codelist_violations_count += 1
            if not include_codelist_violations:
                continue  # Skip codelist violations when excluding them
        filtered_violations.append(v)
    
    # Use filtered violations for summary generation
    violations = filtered_violations
    
    # Group violations by resultPath -> normalizedErrorMessage -> nodeType
    # Store both normalized message (for grouping) and full messages (for examples)
    # Also store values, severities, and their associated focus nodes
    grouped = defaultdict(lambda: defaultdict(lambda: defaultdict(lambda: {'focus_nodes': [], 'values': [], 'severities': [], 'full_messages': set()})))
    
    # Count by constraint component (total)
    component_counts = defaultdict(int)
    
    # Count by constraint component and property (for subtotals)
    component_counts_by_property = defaultdict(lambda: defaultdict(int))
    
    # Extract node types and group
    for v in violations:
        node_type = extract_node_type(v.get('sourceShape'))
        result_path = v.get('resultPath', 'Unknown')
        result_message = v.get('resultMessage', 'Unknown')
        normalized_message = normalize_error_message(result_message)
        constraint_type = extract_constraint_type(result_message)
        value = normalize_value(v.get('value'))  # Normalize value to replace file:// URIs
        severity = v.get('severity')
        
        # Group by normalized message, but store full message for reference
        grouped[result_path][normalized_message][node_type]['focus_nodes'].append(v.get('focusNode'))
        grouped[result_path][normalized_message][node_type]['values'].append(value)
        grouped[result_path][normalized_message][node_type]['severities'].append(severity)
        grouped[result_path][normalized_message][node_type]['full_messages'].add(result_message)
        
        # Count by constraint type (total)
        component_counts[constraint_type] += 1
        
        # Count by constraint type and property (for subtotals)
        property_name = extract_property_name(result_path)
        component_counts_by_property[constraint_type][property_name] += 1
    
    # Write summary
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("SHACL Validation Violations Summary\n")
        f.write("=" * 60 + "\n\n")
        
        # Display command if provided
        if command:
            f.write("Command: " + command + "\n\n")
        
        # Node type counts from source data file
        if node_type_counts:
            f.write("Node Types in Source Data File\n")
            f.write("-" * 60 + "\n")
            # Sort by count (descending), then by name
            sorted_types = sorted(node_type_counts.items(), key=lambda x: (-x[1], x[0]))
            for node_type, count in sorted_types:
                f.write(f"  {node_type}: {count}\n")
            f.write("\n")
        
        # Total violations
        f.write(f"Total Violations: {len(violations)}\n")
        if not include_codelist_violations and codelist_violations_count > 0:
            f.write(f"(Excluded {codelist_violations_count} violation(s) from imported codelists)\n")
        elif include_codelist_violations and codelist_violations_count > 0:
            f.write(f"(Including {codelist_violations_count} violation(s) from imported codelists)\n")
        f.write("\n")
        
        # Constraint component summary with property subtotals
        f.write("Violations by Constraint Component Type\n")
        f.write("-" * 60 + "\n")
        for comp_type, count in sorted(component_counts.items(), key=lambda x: x[0]):
            f.write(f"  {comp_type}: {count}\n")
            # Show subtotals by property (alphabetized)
            property_counts = component_counts_by_property[comp_type]
            for prop_name, prop_count in sorted(property_counts.items(), key=lambda x: x[0]):
                f.write(f"    - {prop_name}: {prop_count}\n")
        f.write("\n")
        
        # Detailed breakdown
        f.write("Detailed Violation Breakdown\n")
        f.write("-" * 60 + "\n\n")
        
        # Sort by resultPath, then by resultMessage, then by nodeType
        sorted_paths = sorted(grouped.items())
        
        for result_path, messages_dict in sorted_paths:
            property_name = extract_property_name(result_path)
            f.write(f"Property: {property_name}\n")
            f.write("=" * 60 + "\n")
            
            sorted_messages = sorted(messages_dict.items())
            
            for normalized_message, node_types_dict in sorted_messages:
                f.write(f"\n  Error Message: {normalized_message}\n")
                f.write("-" * 60 + "\n")
                
                sorted_node_types = sorted(node_types_dict.items())
                
                for node_type, data in sorted_node_types:
                    focus_nodes = data['focus_nodes']
                    values = data['values']
                    severities = data['severities']
                    # Filter out None values
                    valid_nodes = [n for n in focus_nodes if n is not None]
                    count = len(focus_nodes)
                    unique_nodes = sorted(set(valid_nodes))
                    
                    # Get unique severities for this group and extract clean names
                    unique_severities = sorted(set([extract_severity_name(s) for s in severities if s is not None]))
                    severity_display = ", ".join(unique_severities) if unique_severities else "Not specified"
                    
                    f.write(f"\n    Node Type: {node_type}\n")
                    f.write(f"    Count: {count}\n")
                    f.write(f"    Severity: {severity_display}\n")
                    f.write(f"    Affected Focus Nodes ({len(unique_nodes)} unique):\n")
                    
                    # Create a list of (node, value, severity) tuples for display
                    node_value_severity_tuples = []
                    for i, node in enumerate(focus_nodes):
                        value = values[i] if i < len(values) else None
                        severity = severities[i] if i < len(severities) else None
                        node_value_severity_tuples.append((node, value, severity))
                    
                    # Group by unique nodes and show their values
                    node_to_values = {}
                    for node, value, severity in node_value_severity_tuples:
                        if node not in node_to_values:
                            node_to_values[node] = []
                        if value is not None:
                            node_to_values[node].append(value)
                    
                    for node in unique_nodes:
                        node_values = node_to_values.get(node, [])
                        if node_values:
                            # Show unique values for this node
                            unique_values = sorted(set(node_values))
                            if len(unique_values) == 1:
                                f.write(f"      - {node}\n")
                                f.write(f"        Value: {unique_values[0]}\n")
                            else:
                                f.write(f"      - {node}\n")
                                f.write(f"        Values ({len(unique_values)} unique):\n")
                                for val in unique_values:
                                    f.write(f"          - {val}\n")
                        else:
                            f.write(f"      - {node}\n")
                            f.write(f"        Value: (not specified)\n")
                    
                    f.write("\n")
                
            f.write("\n")
    
    print(f"Summary written to: {output_file}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python summarize_shacl_violations.py [--code-violations] <validation_report.ttl> [output.txt]")
        sys.exit(1)
    
    # Parse command-line arguments
    include_codelist_violations = False
    command = None
    node_type_counts_str = None
    input_file = None
    output_file = None
    
    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == '--code-violations':
            include_codelist_violations = True
            i += 1
        elif arg == '--command':
            if i + 1 < len(sys.argv):
                command = sys.argv[i + 1]
                i += 2
            else:
                print("Error: --command requires a value")
                sys.exit(1)
        elif arg == '--node-types':
            if i + 1 < len(sys.argv):
                node_type_counts_str = sys.argv[i + 1]
                i += 2
            else:
                print("Error: --node-types requires a value")
                sys.exit(1)
        elif input_file is None:
            input_file = arg
            i += 1
        elif output_file is None:
            output_file = arg
            i += 1
        else:
            print(f"Warning: Unexpected argument: {arg}")
            i += 1
    
    if input_file is None:
        print("Error: Validation report file is required")
        print("Usage: python summarize_shacl_violations.py [--code-violations] [--command CMD] <validation_report.ttl> [output.txt]")
        sys.exit(1)
    
    if output_file is None:
        output_file = input_file.replace('.ttl', '_summary.txt')
    
    # Parse node type counts if provided
    node_type_counts = None
    if node_type_counts_str:
        try:
            node_type_counts = json.loads(node_type_counts_str)
        except json.JSONDecodeError:
            print(f"Warning: Failed to parse node type counts: {node_type_counts_str}")
            node_type_counts = None
    
    print(f"Parsing validation report: {input_file}")
    violations = parse_validation_report(input_file)
    print(f"Found {len(violations)} violations")
    
    print(f"Generating summary...")
    generate_summary(violations, output_file, include_codelist_violations, command, node_type_counts)
    print("Done!")

if __name__ == '__main__':
    main()

