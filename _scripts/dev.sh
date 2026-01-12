#!/bin/bash

# Script to run Jekyll site locally
# This script installs dependencies and starts the Jekyll development server

set -e

echo "Installing Ruby dependencies..."
gem install bundler
bundle install

echo "Starting Jekyll development server..."
bundle exec jekyll serve
