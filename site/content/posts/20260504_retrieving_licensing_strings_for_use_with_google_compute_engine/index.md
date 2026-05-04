---
title: Retrieving licensing strings for use with Google Compute Engine
url: /retrieving_licensing_strings_for_use_with_google_compute_engine
date: 2026-05-04 11:00:00+02:00
tags: ["gcp", "gce", "windows", "sql", "ubuntu", "licensing"]
---

When migrating server instances to Google Cloud it can be required to change licensing for the sofware that is running within the instance. This can be to use pay-as-you-go (PAYG) licensing for products such as SQL Server or adding additional support packages for Linux derivatives. 

[Google Cloud provides an API](https://docs.cloud.google.com/compute/docs/reference/rest/v1/licenses/list) for iterating licenses available on the platform, that can be added to the boot disk to inform the platform of its use (ensuring billing, technical integration, ...). 

Here are some examples on using the API to retrieve license strings which can then be used to [manage licenses for VMs in Google Compute Engine](https://docs.cloud.google.com/compute/docs/licenses/manage) or for [Migrate to Virtual Machines](https://docs.cloud.google.com/migrate/virtual-machines/docs/5.0/migrate/migrating-vms#license-type) when migrating instances to Google Cloud.

## Ubuntu Pro licenses

```shell
baseUri="https://compute.googleapis.com/compute/v1/projects"
token=`gcloud auth print-access-token`

project="ubuntu-os-pro-cloud"
filter=`echo "licenseCode=2592866803419978320 OR licenseCode=6383960536289251289 OR licenseCode=3242930272766215801 OR licenseCode=2176054482269786025" | jq -Rr @uri`
curl -s \
  "${baseUri}/${project}/global/licenses?filter=${filter}" \
  --header "Authorization: Bearer ${token}" \
  --header "Accept: application/json" \
  --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.appendableToDisk) \(.removableFromDisk) \(.allowedReplacementLicenses // [] | join(",")) \(.selfLink)"' | column -s' ' -t -N Name,Code,Appendable,Removable,Replacements,Uri
```

**Output**

```
Name                              Code                 Appendable  Removable  Replacements                                                                     Uri
ubuntu-pro-2204-lts               2592866803419978320  true        false      5511465778777431107,6383960536289251289,3242930272766215801,2176054482269786025  https://www.googleapis.com/compute/v1/projects/ubuntu-os-pro-cloud/global/licenses/ubuntu-pro-2204-lts
ubuntu-pro-2404-lts               2176054482269786025  true        false      3242930272766215801                                                              https://www.googleapis.com/compute/v1/projects/ubuntu-os-pro-cloud/global/licenses/ubuntu-pro-2404-lts
ubuntu-pro-fips-updates-2204-lts  6383960536289251289  true        false                                                                                       https://www.googleapis.com/compute/v1/projects/ubuntu-os-pro-cloud/global/licenses/ubuntu-pro-fips-updates-2204-lts
```

##  Windows Server licenses

```shell
baseUri="https://compute.googleapis.com/compute/v1/projects"
token=`gcloud auth print-access-token`

project="windows-cloud"
filter=`echo "name = windows-server-20*" | jq -Rr @uri`
curl -s \
  "${baseUri}/${project}/global/licenses?filter=${filter}" \
  --header "Authorization: Bearer ${token}" \
  --header "Accept: application/json" \
  --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.appendableToDisk) \(.removableFromDisk) \(.allowedReplacementLicenses // [] | join(",")) \(.selfLink)"' | column -s' ' -t -N Name,Code,Appendable,Removable,Replacements,Uri
```

**Output**

```
Name                                        Code                 Appendable  Removable  Replacements                                                                                 Uri
windows-server-2000                         5507061839551517143  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2000
windows-server-2003                         5030842449011296880  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2003
windows-server-2004-dc                      6710259852346942597  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2004-dc
windows-server-2008                         1656378918552316916  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2008
windows-server-2008-dc                      1000502              false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2008-dc
windows-server-2008-r2                      3284763237085719542  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2008-r2
windows-server-2008-r2-byol                 4551215591257167608  false       false      1000000,1000015,1000017,1000213,3389558045860892917,4079807029871201927,7142647615590922601  https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2008-r2-byol
windows-server-2008-r2-dc                   1000000              false       false      1000015,1000017,1000213,3389558045860892917,4079807029871201927,7142647615590922601          https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2008-r2-dc
windows-server-2012                         7695108898142923768  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2012
windows-server-2012-byol                    5559842820536817947  false       false      1000015,1000017,1000213,3389558045860892917,4079807029871201927,7142647615590922601          https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2012-byol
windows-server-2012-dc                      1000015              false       false      1000017,1000213,3389558045860892917,4079807029871201927,7142647615590922601                  https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2012-dc
windows-server-2012-r2                      7798417859637521376  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2012-r2
windows-server-2012-r2-byol                 6738952703547430631  false       false      1000017,1000213,3389558045860892917,4079807029871201927,7142647615590922601                  https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2012-r2-byol
windows-server-2012-r2-dc                   1000017              true        false      1000213,3389558045860892917,4079807029871201927,7142647615590922601                          https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2012-r2-dc
windows-server-2016                         4819555115818134498  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2016
windows-server-2016-byol                    4322823184804632846  false       false      1000213,3389558045860892917,4079807029871201927,7142647615590922601                          https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2016-byol
windows-server-2016-dc                      1000213              true        false      3389558045860892917,4079807029871201927,7142647615590922601                                  https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2016-dc
windows-server-2019                         4874454843789519845  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2019
windows-server-2019-byol                    6532438499690676691  false       false      3389558045860892917,4079807029871201927,7142647615590922601                                  https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2019-byol
windows-server-2019-dc                      3389558045860892917  true        false      4079807029871201927,7142647615590922601                                                      https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2019-dc
windows-server-2022                         6107784707477449232  false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2022
windows-server-2022-byol                    2808834792899686364  false       false      4079807029871201927,7142647615590922601                                                      https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2022-byol
windows-server-2022-dc                      4079807029871201927  true        false      7142647615590922601                                                                          https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2022-dc
windows-server-2025                         973054079889996136   false       false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025
windows-server-2025-byol                    6621875542391421291  false       false      7142647615590922601                                                                          https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025-byol
windows-server-2025-dc                      7142647615590922601  true        false                                                                                                   https://www.googleapis.com/compute/v1/projects/windows-cloud/global/licenses/windows-server-2025-dc
```

## SQL Server licenses

```shell
baseUri="https://compute.googleapis.com/compute/v1/projects"
token=`gcloud auth print-access-token`

project="windows-sql-cloud"
filter=`echo "name = sql-*" | jq -Rr @uri`
curl -s \
  "${baseUri}/${project}/global/licenses?filter=${filter}" \
  --header "Authorization: Bearer ${token}" \
  --header "Accept: application/json" \
  --compressed | jq -r '.items[] | "\(.name) \(.licenseCode) \(.appendableToDisk) \(.removableFromDisk) \(.allowedReplacementLicenses // [] | join(",")) \(.selfLink)"' | column -s' ' -t -N Name,Code,Appendable,Removable,Replacements,Uri
```

**Output**
```
sql-server-2012-enterprise  1000222              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2012-enterprise
sql-server-2012-standard    1000220              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2012-standard
sql-server-2012-web         1000223              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2012-web
sql-server-2014-enterprise  1000216              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2014-enterprise
sql-server-2014-standard    1000215              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2014-standard
sql-server-2014-web         1000217              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2014-web
sql-server-2016-enterprise  1000219              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2016-enterprise
sql-server-2016-express     1000225              false       false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2016-express
sql-server-2016-standard    1000218              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2016-standard
sql-server-2016-web         1000224              true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2016-web
sql-server-2017-enterprise  1741222371620352982  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2017-enterprise
sql-server-2017-express     4315490921280396     false       false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2017-express
sql-server-2017-standard    6795597790302237536  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2017-standard
sql-server-2017-web         3398668354433905558  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2017-web
sql-server-2019-enterprise  3039072951948447844  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2019-enterprise
sql-server-2019-express     6367554477567938683  false       false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2019-express
sql-server-2019-standard    3042936622923550835  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2019-standard
sql-server-2019-web         6213885950785916969  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2019-web
sql-server-2022-enterprise  1239729342351313064  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2022-enterprise
sql-server-2022-express     2745185555069962241  false       false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2022-express
sql-server-2022-standard    7764068523658872858  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2022-standard
sql-server-2022-web         1086120352405948436  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2022-web
sql-server-2025-enterprise  2884288503322349663  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2025-enterprise
sql-server-2025-standard    8893652039163547754  true        false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2025-standard
sql-server-2025-web         9049461577077854368  false       false                    https://www.googleapis.com/compute/v1/projects/windows-sql-cloud/global/licenses/sql-server-2025-web
```