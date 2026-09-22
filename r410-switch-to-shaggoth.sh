#!/bin/bash
# Switch R410's physical display to Shaggoth (TTY2)

echo "Switching R410 display to Shaggoth AI (TTY2)..."
ssh matt@100.65.34.60 "sudo chvt 2"
echo "✓ R410 now showing Shaggoth on TTY2"
