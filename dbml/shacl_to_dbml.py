#!/usr/bin/env python3
"""
Convert SHACL shapes to DBML format.
This script parses a SHACL TTL file and generates a complete DBML schema
with all tables and relationships properly defined.
Usage: python3 dbml/shacl_to_dbml.py <shacl_file.ttl> <output_file.dbml>
Example: python3 dbml/shacl_to_dbml.py validation/shacl/sff.shacl.ttl dbml/sff_generated2.dbml
"""

import sys
import argparse
import re
from collections import defaultdict
from rdflib import Graph, Namespace, URIRef, Literal
from rdflib.namespace import RDF, RDFS, XSD, SH 

# Define namespaces
CIDS = Namespace("https://ontology.commonapproach.org/cids#")
SFF = Namespace("https://ontology.commonapproach.org/sff#")
ORG = Namespace("http://ontology.eil.utoronto.ca/tove/organization#")
I72 = Namespace("http://ontology.eil.utoronto.ca/ISO21972/iso21972#")
IC = Namespace("http://ontology.eil.utoronto.ca/tove/icontact#")
FOAF = Namespace("http://xmlns.com/foaf/0.1/")
PROV = Namespace("http://www.w3.org/ns/prov#")
SCH = Namespace("http://schema.org/")

# Map XSD datatypes to DBML types
XSD_TO_DBML = {
    XSD.string: "string",
    XSD.integer: "integer",
    XSD.nonNegativeInteger: "integer",
    XSD.dateTime: "datetime",
    XSD.date: "date",
    XSD.boolean: "boolean",
    XSD.float: "float",
    XSD.double: "double",
    XSD.anyURI: "string",  # Store URI as string
}

# Map namespace prefixes to short names for display
NS_PREFIXES = {
    str(CIDS): "cids",
    str(SFF): "sff",
    str(ORG): "org",
    str(I72): "i72",
    str(IC): "ic",
    str(FOAF): "foaf",
    str(PROV): "prov",
    str(SCH): "sch",
}


def get_local_name(uri):
    """Extract local name from URI."""
    if isinstance(uri, URIRef):
        uri_str = str(uri)
    else:
        uri_str = uri
    
    # Try to split by # or / and take the last part
    if '#' in uri_str:
        return uri_str.split('#')[-1]
    elif '/' in uri_str:
        return uri_str.split('/')[-1]
    return uri_str


def get_table_name(class_uri):
    """Convert class URI to table name."""
    return get_local_name(class_uri)


def get_property_name(property_uri):
    """Convert property URI to column name."""
    return get_local_name(property_uri)


def xsd_to_dbml_type(datatype):
    """Convert XSD datatype to DBML type."""
    if datatype in XSD_TO_DBML:
        return XSD_TO_DBML[datatype]
    return "string"  # Default to string


def is_subclass_of(g, class_uri, superclass_uri):
    """Check if a class is a subclass of another class (transitive)."""
    if class_uri == superclass_uri:
        return True
    
    # Get all classes this class is a subclass of (direct and transitive)
    visited = set()
    to_check = [class_uri]
    
    while to_check:
        current = to_check.pop()
        if current in visited:
            continue
        visited.add(current)
        
        # Check direct subclass relationships
        superclasses = list(g.objects(current, RDFS.subClassOf))
        if superclass_uri in superclasses:
            return True
        
        # Add superclasses to check list for transitive relationships
        to_check.extend(superclasses)
    
    return False


def get_subclasses(g, base_class):
    """Find all classes that are subclasses of a given base class."""
    subclasses = set()
    subclasses.add(base_class)  # Include base class itself
    
    # Find all classes that are direct subclasses
    direct_subclasses = list(g.subjects(RDFS.subClassOf, base_class))
    subclasses.update(direct_subclasses)
    
    # Find transitive subclasses (subclasses of subclasses)
    to_process = list(direct_subclasses)
    processed = set(direct_subclasses)
    
    while to_process:
        current = to_process.pop()
        if current in processed:
            continue
        processed.add(current)
        
        # Find subclasses of current class
        sub_subclasses = list(g.subjects(RDFS.subClassOf, current))
        subclasses.update(sub_subclasses)
        to_process.extend(sub_subclasses)
    
    return subclasses


def get_organization_subclasses(g):
    """Find all classes that are subclasses of cids:Organization."""
    return get_subclasses(g, CIDS.Organization)


def get_code_subclasses(g):
    """Find all classes that are subclasses of cids:Code."""
    return get_subclasses(g, CIDS.Code)


def parse_shacl_file(shacl_file, collapse_org_subclasses=True, collapse_code_subclasses=False):
    """Parse SHACL file and extract schema information.
    
    Args:
        shacl_file: Path to SHACL TTL file
        collapse_org_subclasses: If True, merge all Organization subclasses into Organization table
        collapse_code_subclasses: If True, merge all Code subclasses into Code table
    """
    g = Graph()
    g.parse(shacl_file, format='turtle')
    
    # Find all NodeShapes
    node_shapes = {}
    property_shapes = defaultdict(list)
    class_to_table_map = {}  # Map class URI to table name
    
    # Find all NodeShapes and their target classes
    for node_shape in g.subjects(RDF.type, SH.NodeShape):
        # Get target class
        target_classes = list(g.objects(node_shape, SH.targetClass))
        if not target_classes:
            continue
        
        for target_class in target_classes:
            # Determine table name based on collapse settings
            is_org_subclass = is_subclass_of(g, target_class, CIDS.Organization)
            is_code_subclass = is_subclass_of(g, target_class, CIDS.Code)
            
            if collapse_org_subclasses and is_org_subclass:
                class_name = "Organization"
                base_uri = CIDS.Organization
            elif collapse_code_subclasses and is_code_subclass:
                class_name = "Code"
                base_uri = CIDS.Code
            else:
                class_name = get_table_name(target_class)
                base_uri = target_class
            
            # Map class URI to table name
            class_to_table_map[str(target_class)] = class_name
            
            # Get properties for this NodeShape
            properties = list(g.objects(node_shape, SH.property))
            
            # If table already exists, merge properties
            if class_name in node_shapes:
                # Merge properties
                node_shapes[class_name]['properties'].extend(properties)
            else:
                node_shapes[class_name] = {
                    'uri': base_uri,
                    'properties': properties,
                    'node_shape': node_shape
                }
            
            # Store property shapes
            for prop_shape in properties:
                property_shapes[class_name].append(prop_shape)
    
    return g, node_shapes, property_shapes, class_to_table_map


def extract_property_info(g, prop_shape, class_name):
    """Extract property information from a PropertyShape."""
    prop_info = {
        'name': None,
        'path': None,
        'datatype': None,
        'target_class': None,
        'min_count': None,
        'max_count': None,
        'required': False,
    }
    
    # Get property name
    name_literals = list(g.objects(prop_shape, SH.name))
    if name_literals:
        prop_info['name'] = str(name_literals[0])
    
    # Get property path
    paths = list(g.objects(prop_shape, SH.path))
    if paths:
        prop_info['path'] = paths[0]
        # If no name, use path
        if not prop_info['name']:
            prop_info['name'] = get_property_name(paths[0])
    
    # Get datatype (for literal properties)
    datatypes = list(g.objects(prop_shape, SH.datatype))
    if datatypes:
        prop_info['datatype'] = datatypes[0]
    
    # Get target class (for object properties)
    # sh:class is accessed via URIRef since it's a Python keyword
    sh_class = URIRef("http://www.w3.org/ns/shacl#class")
    target_classes = list(g.objects(prop_shape, sh_class))
    if target_classes:
        prop_info['target_class'] = target_classes[0]
    
    # Get cardinality constraints
    min_counts = list(g.objects(prop_shape, SH.minCount))
    if min_counts:
        prop_info['min_count'] = int(min_counts[0])
        prop_info['required'] = prop_info['min_count'] > 0
    
    max_counts = list(g.objects(prop_shape, SH.maxCount))
    if max_counts:
        prop_info['max_count'] = int(max_counts[0])
    
    return prop_info


def generate_dbml(shacl_file, output_file=None, collapse_org_subclasses=True, collapse_code_subclasses=False):
    """Generate DBML from SHACL file.
    
    Args:
        shacl_file: Path to SHACL TTL file
        output_file: Optional output file path (prints to stdout if None)
        collapse_org_subclasses: If True, merge all Organization subclasses into Organization table
        collapse_code_subclasses: If True, merge all Code subclasses into Code table
    """
    g, node_shapes, property_shapes, class_to_table_map = parse_shacl_file(
        shacl_file, 
        collapse_org_subclasses=collapse_org_subclasses,
        collapse_code_subclasses=collapse_code_subclasses
    )
    
    # Collect all table definitions and relationships
    tables = {}
    relationships = []
    
    # Process each class/node shape
    for class_name, class_info in node_shapes.items():
        table_columns = []
        table_relationships = []
        seen_columns = set()  # Track columns to avoid duplicates
        
        # Process each property shape
        for prop_shape in property_shapes[class_name]:
            prop_info = extract_property_info(g, prop_shape, class_name)
            
            if not prop_info['name']:
                continue
            
            prop_name = prop_info['name']
            
            # Check if this is a relationship (object property)
            if prop_info['target_class']:
                # Map target class to table name using class_to_table_map
                target_class_uri = str(prop_info['target_class'])
                if target_class_uri in class_to_table_map:
                    target_class_name = class_to_table_map[target_class_uri]
                else:
                    # Check if it's a subclass that should be collapsed
                    target_class_ref = prop_info['target_class']
                    if isinstance(target_class_ref, URIRef):
                        if collapse_org_subclasses and is_subclass_of(g, target_class_ref, CIDS.Organization):
                            target_class_name = "Organization"
                        elif collapse_code_subclasses and is_subclass_of(g, target_class_ref, CIDS.Code):
                            target_class_name = "Code"
                        else:
                            target_class_name = get_table_name(target_class_ref)
                    else:
                        target_class_name = get_table_name(prop_info['target_class'])
                
                # Create foreign key column name
                fk_column_name = f"{prop_name}_id"
                
                # Skip if column already exists
                if fk_column_name in seen_columns:
                    continue
                seen_columns.add(fk_column_name)
                
                # Add column to table
                nullable = " [not null]" if prop_info['required'] else ""
                table_columns.append(f"  {fk_column_name} URI{nullable}")
                
                # Store relationship
                table_relationships.append({
                    'from_table': class_name,
                    'from_column': fk_column_name,
                    'to_table': target_class_name,
                    'property_name': prop_name
                })
            
            # Check if this is a literal property
            elif prop_info['datatype']:
                # Skip if column already exists
                if prop_name in seen_columns:
                    continue
                seen_columns.add(prop_name)
                
                dbml_type = xsd_to_dbml_type(prop_info['datatype'])
                nullable = " [not null]" if prop_info['required'] else ""
                table_columns.append(f"  {prop_name} {dbml_type}{nullable}")
        
        # Store table definition
        if table_columns:
            tables[class_name] = {
                'columns': table_columns,
                'relationships': table_relationships
            }
    
    # Generate DBML output
    output_lines = [
        "// SFF Project - Full ERD (Generated from SHACL)",
        "// Use URI for @id properties as requested",
        ""
    ]
    
    # Generate table definitions
    for table_name in sorted(tables.keys()):
        output_lines.append(f"Table {table_name} {{")
        output_lines.append("  id URI [pk]")
        
        for column in tables[table_name]['columns']:
            output_lines.append(column)
        
        output_lines.append("}")
        output_lines.append("")
    
    # Generate table groups for visual clustering
    output_lines.append("// Visual Clustering for the Renderer")
    output_lines.append("")
    
    # Define table groups
    # Note: Code is included in Code_Values when Code subclasses are collapsed
    table_groups = {
        "Organizations": ["Organization", "OrganizationID", "Address", "Person"],
        "Reporting_and_Metrics": ["Indicator", "IndicatorReport", "Outcome", "Measure", "Theme", "ReportInfo"],
        "Profiles": ["OrganizationProfile", "TeamProfile", "EDGProfile", "FundingStatus"],
        "Code_Values": ["Sector", "ProvinceTerritory", "Locality", "OrganizationType", 
                       "FundingState", "EquityDeservingGroup", "PopulationServed", 
                       "Characteristic", "Code"]  # Code included when subclasses are collapsed
    }
    
    # Generate table groups (only include tables that exist)
    for group_name, group_tables in table_groups.items():
        # Filter to only include tables that exist
        existing_tables = [t for t in group_tables if t in tables]
        
        if existing_tables:
            output_lines.append(f"TableGroup {group_name} {{")
            for table in existing_tables:
                output_lines.append(f"  {table}")
            output_lines.append("}")
            output_lines.append("")
    
    # Generate relationships section
    output_lines.append("// Relationships and Foreign Keys")
    output_lines.append("")
    
    # Group relationships by category
    org_relationships = []
    indicator_relationships = []
    profile_relationships = []
    theme_relationships = []
    code_relationships = []
    other_relationships = []
    
    for table_name in sorted(tables.keys()):
        for rel in tables[table_name]['relationships']:
            # Only include relationships where both tables exist
            if rel['to_table'] not in tables:
                continue
            
            rel_line = f"Ref: {rel['to_table']}.id < {rel['from_table']}.{rel['from_column']}"
            comment = f" // {rel['property_name']}"
            
            # Categorize relationships
            if 'Organization' in rel['to_table'] or 'Organization' in rel['from_table']:
                org_relationships.append(rel_line + comment)
            elif 'Indicator' in rel['to_table'] or 'Indicator' in rel['from_table']:
                indicator_relationships.append(rel_line + comment)
            elif 'Profile' in rel['to_table'] or 'Profile' in rel['from_table'] or 'Team' in rel['to_table']:
                profile_relationships.append(rel_line + comment)
            elif 'Theme' in rel['to_table'] or 'Theme' in rel['from_table']:
                theme_relationships.append(rel_line + comment)
            elif 'Code' in rel['to_table'] or 'Code' in rel['from_table']:
                code_relationships.append(rel_line + comment)
            else:
                other_relationships.append(rel_line + comment)
    
    # Output categorized relationships
    if org_relationships:
        output_lines.append("// Organization Components")
        for rel in org_relationships:
            output_lines.append(rel)
        output_lines.append("")
    
    if indicator_relationships:
        output_lines.append("// Indicator & Report Links")
        for rel in indicator_relationships:
            output_lines.append(rel)
        output_lines.append("")
    
    if profile_relationships:
        output_lines.append("// Profiles & Teams")
        for rel in profile_relationships:
            output_lines.append(rel)
        output_lines.append("")
    
    if theme_relationships:
        output_lines.append("// Hierarchical / Thematic Links")
        for rel in theme_relationships:
            output_lines.append(rel)
        output_lines.append("")
    
    if code_relationships:
        output_lines.append("// Code & Values")
        for rel in code_relationships:
            output_lines.append(rel)
        output_lines.append("")
    
    if other_relationships:
        output_lines.append("// Other Relationships")
        for rel in other_relationships:
            output_lines.append(rel)
        output_lines.append("")
    
    # Write output
    output_text = "\n".join(output_lines)
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(output_text)
        print(f"DBML file written to: {output_file}")
    else:
        print(output_text)
    
    return output_text


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Convert SHACL shapes to DBML format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Default: collapse Organization subclasses, expand Code subclasses
  python3 shacl_to_dbml.py validation/shacl/sff.shacl.ttl output.dbml
  
  # Collapse both Organization and Code subclasses
  python3 shacl_to_dbml.py --collapse-org --collapse-code validation/shacl/sff.shacl.ttl output.dbml
  
  # Expand all subclasses (keep separate tables)
  python3 shacl_to_dbml.py --no-collapse-org --no-collapse-code validation/shacl/sff.shacl.ttl output.dbml
        """
    )
    
    parser.add_argument('shacl_file', help='Path to SHACL TTL file')
    parser.add_argument('output_file', nargs='?', help='Output DBML file (prints to stdout if not provided)')
    
    parser.add_argument(
        '--collapse-org',
        action='store_true',
        default=True,
        help='Collapse Organization subclasses into Organization table (default: True)'
    )
    parser.add_argument(
        '--no-collapse-org',
        dest='collapse_org',
        action='store_false',
        help='Keep Organization subclasses as separate tables'
    )
    
    parser.add_argument(
        '--collapse-code',
        action='store_true',
        default=False,
        help='Collapse Code subclasses into Code table (default: False)'
    )
    parser.add_argument(
        '--no-collapse-code',
        dest='collapse_code',
        action='store_false',
        help='Keep Code subclasses as separate tables (default)'
    )
    
    args = parser.parse_args()
    
    try:
        generate_dbml(
            args.shacl_file,
            args.output_file,
            collapse_org_subclasses=args.collapse_org,
            collapse_code_subclasses=args.collapse_code
        )
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

