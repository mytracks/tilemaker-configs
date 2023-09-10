#!/bin/bash

docker run -u 1000 --cpus=10 --rm -ti -v "/data":/data mytracks/tilemaker $1

