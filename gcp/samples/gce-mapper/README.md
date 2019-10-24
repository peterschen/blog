# GCE Mapper #
GCE Mapper is a utility written in Python that matches exitisting compute configurations to corresponding Google Cloud Engine (GCE) machine types. Data for matching is collected from the target [Google Cloud Platform (GCP) project](https://cloud.google.com/resource-manager/docs/creating-managing-projects). Existing configurations can either be supplied as comma seperated values (.csv) or Microsoft Excel (.xlsx) document.

## Inputs ##
GCE Mapper requires two inputs: GCE machine types and a list of the existing configurations

### GCE machine types ###
The available machine types can either be downloaded automatically from the target project. For this to work authentication needs to set up properly. You can either use [user authentication](https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login) if you have access to the target project or [use a service account](https://cloud.google.com/docs/authentication/getting-started) which has the correct permissions.

You need permissions to the [`compute.machineTypes.list`](https://cloud.google.com/compute/docs/reference/rest/v1/machineTypes/list) method. Standard roles that carry this permissions are: [Compute Viewer](https://cloud.google.com/compute/docs/access/iam#compute.networkViewer), [Compute Admin](https://cloud.google.com/compute/docs/access/iam#compute.admin), [Compute Instance Admin (v1)](https://cloud.google.com/compute/docs/access/iam#compute.instanceAdmin.v1)

### Configurations ###
Existing configuration can be supplied in CSV and Excel format from local disk. For both formats two columns need to be in the document: `cpus` and `memory`. The `cpus` column contains the number of vCPUs and `memory` denotes the amount of memory in Megabytes.

The location of the columns does not matter as they are selected by name instead of location.

#### Comma Seperated Value (csv) ####
The delimiter for CSV is a colon (`,`). This first line of the document needs to contain the header so that GCE Mapper can access the correct fields.

![Sample input in CSV format](sample-input-csv.png?raw=true)

#### Excel (xlsx) ####
The required fields (`cpu` and `memory`) should be formatted as a number and not denoted as a string to ensure correct mapping.

![Sample input in Excel format](sample-input-xlsx.png?raw=true)

## Output ##
GCE Mapper will write the ouput to the same directory where the input is located. It will create a new file in the same format as the input that was supplied. The file name will have an `-output` suffix to it and the contents of the input document will be appended with matching GCE machine types.

As there will not always be an exact match between a supplied configuration and a pre-defined machine type GCE Mapper applies different matching strategies: `exact`, `closest_cpu` and `closest_memory`.

All three matching strategies are applied and added to the output even though an exact match might have been found.

See the following screenshots for sample output:

![Sample output in CSV format](sample-output-csv.png?raw=true)

![Sample output in Excel format](sample-output-xlsx.png?raw=true)

### `exact` ###
The `exact` matching algorithm will check if the configuration matches exactly a GCE machine type.

### `closest_cpu` ###
The `closest_cpu` matching algorithm will check for a machine type that exactly matches the memory configuration but has either an equal or higher amount of vCPUs attched.

### `closest_memory` ###
The `closest_memory` matching algorithm will check for a machine type that exactly matches the vCPUs configuration but has either an equal or higher amount of memory attched.

## Usage ##
GCE Mapper can be run in two different modes: `download` and `match`. While `download` will help you retrieve the available machine types for the target environment, `match` is used to do the matching against available GCE machine types.

```
usage: mapper.py [-h] [-v] {download,match} ...

Match compute configuration to GCE instances

positional arguments:
  {download,match}
    download        Download GCE machine types
    match           Match configurations against GCE machine types

optional arguments:
  -h, --help        show this help message and exit
  -v                Verbose output
```

### `download` mode ###
```
usage: mapper.py [-h] [-v] {download,match} ...

Match compute configuration to GCE instances

positional arguments:
  {download,match}
    download        Download GCE machine types
    match           Match configurations against GCE machine types

optional arguments:
  -h, --help        show this help message and exit
  -v                Verbose output
```

### `match` mode ###
```
usage: mapper.py [-h] [-v] {download,match} ...

Match compute configuration to GCE instances

positional arguments:
  {download,match}
    download        Download GCE machine types
    match           Match configurations against GCE machine types

optional arguments:
  -h, --help        show this help message and exit
  -v                Verbose output
```