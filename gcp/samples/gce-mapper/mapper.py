#!/usr/bin/env python3

import argparse
import requests
import json
import googleapiclient.discovery
import sqlite3
import pandas
import xlrd

name_file = "gce_machineTypes.json"

db = sqlite3.connect("machineTypes.sqlite")

def main():
    setup_db()

    parser = argparse.ArgumentParser(description = "Match compute configuration to GCE instances")
    subparser = parser.add_subparsers(dest = "action")

    parser_d = subparser.add_parser("download")
    parser_d.add_argument("-p", metavar = "project_id", help = "GCP project id for which to download available machine types", required = True)

    parser_m = subparser.add_parser("match")
    parser_m.add_argument("-d", metavar = "/path/to/file.xlsx", help = "Path to .xlsx document", required=True)
    parser_m.add_argument("-z", metavar = "zone", help = "GCP zone", default = "europe-west3")

    args = parser.parse_args()

    if args.action == "download":
        download_machineTypes(args.p)
        load_machineTypes()
    else:
        match_instance(args.d, args.z)

def match_instance(path_xlsx, zone, loadMachineTypes = False):
    if load_machineTypes == True:
        load_machineTypes()

    cursor = db.cursor()

    x = pandas.ExcelFile(path_xlsx)
    df = x.parse(x.sheet_names[0])

    for name, values in df.iterrows():
        cpus = values[-2]
        memory = values[-1]

        if not pandas.isna(cpus) and not pandas.isna(memory):
            lookup_instace(cpus, memory, zone)

def lookup_instace(guestCpus, memoryMb, zone):
    print("Matching compute configuration with {} vCPUs and {} MB memory to GCE machine types in '{}'".format(guestCpus, memoryMb, zone))

    cursor = db.cursor()
    cursor.execute("SELECT name FROM MachineTypes WHERE guestCpus = ? AND memoryMb = ? AND zone LIKE ? ORDER BY guestCpus, memoryMb LIMIT 0, 1", (guestCpus, memoryMb, "{}%".format(zone)))
    print(cursor.fetchall())

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

main()