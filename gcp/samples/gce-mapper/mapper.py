#!/usr/bin/env python3

import argparse
import requests
import json
import googleapiclient.discovery
import sqlite3
import pandas
import xlrd
import openpyxl
import os

setting_verbose_output = False
name_file = "gce_machineTypes.json"

db = sqlite3.connect("machineTypes.sqlite")

def main():
    setup_db()

    parser = argparse.ArgumentParser(description = "Match compute configuration to GCE instances")
    parser.add_argument("-v", action="store_true", help="Verbose output")

    subparser = parser.add_subparsers(dest = "action")

    parser_d = subparser.add_parser("download")
    parser_d.add_argument("-p", metavar = "project_id", help = "GCP project id for which to download available machine types", required = True)

    parser_m = subparser.add_parser("match")
    group = parser_m.add_mutually_exclusive_group(required = True)
    group.add_argument("-c", metavar = "file.csv", help = "Path to .csv file")
    group.add_argument("-x", metavar = "file.xlsx", help = "Path to .xlsx file")
    parser_m.add_argument("-z", metavar = "zone", help = "GCP zone", default=None)

    args = parser.parse_args()

    global setting_verbose_output
    setting_verbose_output = args.v

    if args.action == "download":
        download_machineTypes(args.p)
        load_machineTypes()
    elif args.action == "match":
        if args.c != None:
            match_csv(args.c, args.z)
        else:
            match_xlsx(args.x, args.z)
    else:
        parser.print_help()

def match_csv(path_csv, zone=None):
    columns = pandas.read_csv(path_csv).columns
    data = pandas.read_csv(path_csv, skiprows=1, names=columns)
    output = iterate_doc(data, zone)
    path_output = get_output_path(path_csv)
    print("Writing output to '{}'".format(path_output))
    output.to_csv(path_output)

def match_xlsx(path_xlsx, zone=None):
    x = pandas.ExcelFile(path_xlsx)
    data = x.parse(x.sheet_names[0])
    output = iterate_doc(data, zone)
    path_output = get_output_path(path_xlsx)
    print("Writing output to '{}'".format(path_output))
    output.to_excel(path_output)

def iterate_doc(data, zone=None):
    matches_exact = []
    matches_cpu = []
    matches_memory = []

    for name, values in data.iterrows():
        cpus = values["cpus"]
        memory = values["memory"]

        if not pandas.isna(cpus) and not pandas.isna(memory):
            result = lookup_instance(cpus, memory, zone)
            
            if result[0] != None:
                matches_exact.append("{} ({} vCPUs/{} MB memory)".format(result[0][0], result[0][1], result[0][2]))
            else:
                matches_exact.append("-")

            if result[1] != None:
                matches_cpu.append("{} ({} vCPUs/{} MB memory)".format(result[1][0], result[1][1], result[1][2]))
            else:
                matches_cpu.append("-")

            if result[2] != None:
                matches_memory.append("{} ({} vCPUs/{} MB memory)".format(result[2][0], result[2][1], result[2][2]))
            else:
                matches_memory.append("-")
        else:
            matches_exact.append("-")
            matches_cpu.append("-")
            matches_memory.append("-")

    data["match_exact"] = matches_exact
    data["match_cpu"] = matches_cpu
    data["match_memory"] = matches_memory
    return data


def lookup_instance(cpus, memory, zone=None):
    match_exact = lookup_exact(cpus, memory, zone)
    match_cpu = lookup_closest_cpu(cpus, memory, zone)
    match_memory = lookup_closest_memory(cpus, memory, zone)

    if match_exact == None and match_cpu == None and match_memory == None:
        log_verbose("No match found for {}/{}".format(cpus, memory))

    return (match_exact, match_cpu, match_memory)

def lookup_exact(cpus, memory, zone=None):
    params = (cpus, memory)
    query = ("SELECT name, guestCpus, memoryMb "
    "FROM MachineTypes "
    "WHERE guestCpus = ? " 
    "AND memoryMb = ? ")

    if zone != None:
        params.append(zone)
        query += " AND zone = ?"

    query += "ORDER BY guestCpus, memoryMb"

    cursor = db.cursor()
    cursor.execute(query, params)
    match = cursor.fetchone()
    
    if match != None:
        log_verbose("Exact match for {} vCPUs / {} MB memory: {} ({} vCPUs / {} MB memory)".format(cpus, memory, match[0], match[1], match[2]))
        return match
    
    return None

def lookup_closest_cpu(cpus, memory, zone=None):
    params = (cpus, memory)
    query = ("SELECT name, guestCpus, memoryMb "
    "FROM MachineTypes "
    "WHERE guestCpus = ? "
    "AND memoryMb >= ? ")
    
    if zone != None:
        params.append(zone)
        query += " AND zone = ?"

    query += "ORDER BY guestCpus, memoryMb"

    cursor = db.cursor()
    cursor.execute(query, params)
    match = cursor.fetchone()

    if match != None:
        log_verbose("CPU match for {} vCPUs / {} MB memory: {} ({} vCPUs / {} MB memory)".format(cpus, memory, match[0], match[1], match[2]))
        return match
    
    return None

def lookup_closest_memory(cpus, memory, zone=None):
    params = (cpus, memory)
    query = ("SELECT name, guestCpus, memoryMb "
    "FROM MachineTypes "
    "WHERE guestCpus >= ? "
    "AND memoryMb = ? ")
    
    if zone != None:
        params.append(zone)
        query += " AND zone = ?"

    query += "ORDER BY guestCpus, memoryMb"

    cursor = db.cursor()
    cursor.execute(query, params)
    match = cursor.fetchone()

    if match != None:
        log_verbose("Memory match for {} vCPUs / {} MB memory: {} ({} vCPUs / {} MB memory)".format(cpus, memory, match[0], match[1], match[2]))
        return match
    
    return None

def download_machineTypes(project_id):
    print("Downloading machine types for project '{}'".format(project_id))
    compute = googleapiclient.discovery.build('compute', 'v1')
    types = compute.machineTypes().aggregatedList(project=project_id, maxResults=4000).execute()

    with open(name_file, "w+") as f:
        print("Writing machine types to '{}'".format(name_file))
        f.write(json.dumps(types))

def load_machineTypes():
    with open(name_file, "r") as f:
        types = json.load(f)

    clean_machineTypes()

    print("Write machine types to database")
    for key, value in types["items"].items():
        if "machineTypes" in value.keys():
            write_machineTypes(value["machineTypes"])

def clean_machineTypes():
    print("Removing machine types from database")
    cursor = db.cursor()
    cursor.execute("DELETE FROM MachineTypes")
    db.commit()

def write_machineTypes(machine_types):
    cursor = db.cursor()

    types = []
    for machine_type in machine_types:
        item = (machine_type["name"], machine_type["description"], machine_type["guestCpus"], machine_type["memoryMb"], machine_type["imageSpaceGb"], machine_type["maximumPersistentDisks"], machine_type["maximumPersistentDisksSizeGb"], machine_type["zone"])
        types.append(item)

    cursor.executemany("INSERT INTO MachineTypes VALUES (?, ?, ?, ?, ?, ?, ?, ?)", types)
    db.commit()

def setup_db():
    cursor = db.cursor()
    cursor.execute("CREATE TABLE IF NOT EXISTS MachineTypes ("
        "name TEXT, "
        "description TEXT, "
        "guestCpus INTEGER, "
        "memoryMb INTEGER, "
        "imageSpaceGb INTEGER, "
        "maximumPersistentDisks INTEGER, "
        "maximumPersistentDisksSizeGb INTEGER, "
        "zone TEXT"
        ")")

def get_output_path(path_input):
    name, extension = os.path.splitext(path_input)
    return "{}-output{}".format(name, extension)

def log_verbose(message):
    if setting_verbose_output == True:
        print(message)

main()