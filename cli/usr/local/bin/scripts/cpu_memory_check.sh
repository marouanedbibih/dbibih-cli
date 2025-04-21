#!/bin/bash

# Check CPU and memory usage
echo "Checking CPU and memory usage..."
top -b -n 1 | head -n 20
