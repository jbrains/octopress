#!/bin/bash

# I don't know how better to specify "the root of this project"
PLUGIN_PRODUCTION_CODE_ROOT="."
bundle exec rspec -I $PLUGIN_PRODUCTION_CODE_ROOT spec
