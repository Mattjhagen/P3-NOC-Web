#!/bin/bash
# Switch R410's physical display back to GUI (TTY1)

echo "Switching R410 display to GUI (TTY1)..."
ssh matt@100.65.34.60 "sudo chvt 1"
echo "✓ R410 now showing GUI login on TTY1"
