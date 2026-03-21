#!/usr/bin/env python3
import re

def parse_echidna_trace(trace):
    """Parse Echidna trace and extract function calls, parameters, delays, and 'from' addresses."""
    calls = []
    last_address = None  # Track the last 'from' address

    for line in trace.strip().splitlines():
        # Parse function calls, including those with underscores
        func_call = re.match(r"Tester\.([a-zA-Z0-9_]+)\(([^)]*)\)", line)
        if func_call:
            func_name = func_call.group(1)
            params = func_call.group(2)

            # Check for 'from' address
            from_address = re.search(r"from: (0x[a-fA-F0-9]+)", line)
            time_delay = re.search(r"Time delay: (\d+)", line)

            # If we have a 'from' address, we need to set it up
            if from_address:
                address = from_address.group(1)
                if address != last_address:
                    # Only set up the actor if the address has changed
                    calls.append(f"_setUpActor({address});")
                    last_address = address

            # Add the delay if it exists
            if time_delay:
                delay_time = time_delay.group(1)
                calls.append(f"_delay({delay_time});")

            # Add the function call
            calls.append(f"Tester.{func_name}({params});")

        # Handle special case of "*wait*" for a delay
        elif "*wait*" in line:
            time_delay = re.search(r"Time delay: (\d+)", line)
            if time_delay:
                delay_time = time_delay.group(1)
                calls.append(f"_delay({delay_time});")

    return calls

def parse_medusa_trace(trace):
    """Parse Medusa trace and extract function calls, parameters, block, time, and sender information."""
    calls = []
    last_address = None  # Track the last 'from' address
    last_block = 0
    last_time = 0

    for line in trace.strip().splitlines():
        # Skip empty lines
        if not line.strip():
            continue
            
        # Parse Medusa format: number) Contract.function(types)(values) (metadata)
        medusa_pattern = r"(?:\d+\))?\s*Tester\.([a-zA-Z0-9_]+)\([^)]*\)\(([^)]*)\)\s*\(block=(\d+),\s*time=(\d+).*sender=(0x[a-fA-F0-9]+)\)"
        match = re.search(medusa_pattern, line)
        
        if match:
            func_name = match.group(1)
            params = match.group(2)
            block = int(match.group(3))
            time = int(match.group(4))
            address = match.group(5)
            
            if (address == "0x10000"):
                actor = "USER1"
            elif (address == "0x20000"):
                actor = "USER2"
            elif (address == "0x30000"):
                actor = "USER3"
            
            # If sender address changed, set up the new actor
            if address != last_address:
                calls.append(f"_setUpActor({actor});")
                last_address = address
                
            # Add block/time delay if needed
            if time > last_time:
                # Medusa reports absolute timestamps, so we calculate the difference
                # between consecutive transactions to determine the delay
                time_diff = time - last_time
                if time_diff > 0:
                    calls.append(f"_delay({time_diff});")
                last_time = time
                last_block = block
                
            # Add the function call
            calls.append(f"Tester.{func_name}({params});")
            
    return calls

def detect_trace_format(trace):
    """Detect whether the trace is in Echidna or Medusa format."""
    # Check for Medusa format indicators (block=X, time=Y, sender=0xZ)
    if re.search(r"\(block=\d+,\s*time=\d+.*sender=0x[a-fA-F0-9]+\)", trace):
        return "medusa"
    # Default to Echidna format
    return "echidna"

def generate_foundry_test(calls, test_name="test_replay"):
    """Generate the Solidity test function code."""
    test_code = [f"function {test_name}() public {{"]
    test_code.extend(f"    {call}" for call in calls)
    test_code.append("}")

    return "\n".join(test_code)

# Ask user to paste the trace
print("Paste your Echidna or Medusa call trace below. Press Enter twice to finish:")
trace = []
while True:
    line = input()
    if line:
        trace.append(line.strip())
    else:
        break
trace = "\n".join(trace)

# Detect format and parse the trace
format_type = detect_trace_format(trace)
if format_type == "medusa":
    print("\nDetected Medusa trace format")
    parsed_calls = parse_medusa_trace(trace)
else:
    print("\nDetected Echidna trace format")
    parsed_calls = parse_echidna_trace(trace)

# Generate the test
solidity_test = generate_foundry_test(parsed_calls)

# Output the generated Solidity test
print("\nGenerated Foundry Test Function:\n")
print(solidity_test)
