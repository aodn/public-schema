# public-schema
Shared schema specifications for data exchange (WFS, CSV, etc...)

Schemas are specified according to the [Table Schema](https://specs.frictionlessdata.io/table-schema) format from [Frictionless Data](https://frictionlessdata.io).

The [frictionless](https://pypi.org/project/frictionless) Python package provides functionality to describe, extract, and validate tabular data (e.g. CSV files). This can be used from within Python code, or from the command line in a Linux shell.

## Set up
All you need is Python (3.6 or higher), and
```shell
pip install frictionless
```
See https://framework.frictionlessdata.io/docs/guides/quick-start/ for more help getting started.

## Basic validation
To validate a local copy of a file against a schema, e.g.,
```shell
public-schema/imos_bgc_db$ frictionless validate --schema NRS_StationInfo.schema.yaml ../sample_data/NRS_StationInfo.csv
# -----
# valid: ../sample_data/NRS_StationInfo.csv
# -----
```
Remote files accessible via a URL can also be validated directly
```shell
public-schema/imos_bgc_db$ frictionless validate --schema NRS_StationInfo.schema.yaml https://raw.githubusercontent.com/PlanktonTeam/IMOS_Toolbox/master/Plankton/RawData/NRS_StationInfo.csv
```
If the file is invalid, `frictionless` provides detailed info on the issues, e.g.,
```shell
# -------
# invalid: ../sample_data/NRS_StationInfo.csv
# -------

===  =====  =================  ============================================================================================================================
row  field  code               message                                                                                                                     
===  =====  =================  ============================================================================================================================
  2      7  type-error         Type error in the cell "1944-10-01 00:00:00" in row "2" and field "STATIONSTARTDATE" at position "7": type is "date/default"
  3      7  type-error         Type error in the cell "2009-11-16 00:00:00" in row "3" and field "STATIONSTARTDATE" at position "7": type is "date/default"
  4      7  type-error         Type error in the cell "2009-05-12 00:00:00" in row "4" and field "STATIONSTARTDATE" at position "7": type is "date/default"
  5      8  type-error         Type error in the cell "null" in row "5" and field "STATIONDEPTH_M" at position "8": type is "number/default"               
  8         primary-key-error  Row at position "8" violates the primary key: the same as in the row at position 6                                          
===  =====  =================  ============================================================================================================================
```
