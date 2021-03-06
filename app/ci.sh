#!/bin/bash

version=$1

cd src
docker build -t eu.gcr.io/slavayssiere-sandbox/app:$version .
docker push eu.gcr.io/slavayssiere-sandbox/app:$version
cd -

helm install --dry-run --debug ./app-chart
helm lint ./app-chart
helm package --version $version ./app-chart

gsutil mv app-chart-$version.tgz gs://charts-wescale-sandbox/app-chart/$version/app-chart-$version.tgz

