#!/usr/bin/env python3
"""
MCP Server Test Script
A simple test script to verify a local MCP (Media Control Protocol) server
running on port 8000.
"""

import socket
import time
import json
import sys
import argparse
from datetime import datetime

class MCPServerTester:
    def __init__(self, host="localhost", port=8000, timeout=5):
        """Initialize the MCP server tester with connection parameters."""
        self.host = host
        self.port = port
        self.timeout = timeout
        self.sock = None
        self.connected = False
        
    def log(self, message, level="INFO"):
        """Log messages with timestamp."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        print(f"[{timestamp}] {level}: {message}")
        
    def connect(self):
        """Establish connection to the MCP server."""
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(self.timeout)
            self.log(f"Connecting to MCP server at {self.host}:{self.port}...")
            self.sock.connect((self.host, self.port))
            self.connected = True
            self.log("Connection established successfully")
            return True
        except socket.error as e:
            self.log(f"Failed to connect to MCP server: {e}", "ERROR")
            return False
    
    def disconnect(self):
        """Close the connection to the MCP server."""
        if self.sock:
            self.sock.close()
            self.connected = False
            self.log("Disconnected from MCP server")
    
    def send_command(self, command, data=None):
        """Send a command to the MCP server and return the response."""
        if not self.connected:
            self.log("Not connected to MCP server", "ERROR")
            return None
            
        try:
            # Prepare command payload
            payload = {
                "command": command,
                "timestamp": datetime.now().isoformat()
            }
            
            if data:
                payload["data"] = data
                
            # Convert command to JSON and send
            command_str = json.dumps(payload) + "\n"
            self.log(f"Sending command: {command}")
            self.sock.sendall(command_str.encode('utf-8'))
            
            # Get response
            response = self.sock.recv(4096).decode('utf-8')
            try:
                parsed_response = json.loads(response)
                self.log(f"Received response: {parsed_response}")
                return parsed_response
            except json.JSONDecodeError:
                self.log(f"Received non-JSON response: {response}")
                return response
                
        except socket.error as e:
            self.log(f"Error sending command: {e}", "ERROR")
            return None
            
    def run_basic_tests(self):
        """Run a series of basic tests to verify server functionality."""
        tests_passed = 0
        tests_failed = 0
        
        self.log("Starting basic MCP server tests", "TEST")
        
        # Test 1: Connect to server
        self.log("Test 1: Connecting to server", "TEST")
        if self.connect():
            tests_passed += 1
            self.log("Test 1: PASSED", "RESULT")
        else:
            tests_failed += 1
            self.log("Test 1: FAILED", "RESULT")
            return (tests_passed, tests_failed)  # Early return if can't connect
            
        # Test 2: Ping/heartbeat
        self.log("Test 2: Sending ping/heartbeat", "TEST")
        response = self.send_command("ping")
        if response and ("status" in response and response["status"] == "ok"):
            tests_passed += 1
            self.log("Test 2: PASSED", "RESULT")
        else:
            tests_failed += 1
            self.log("Test 2: FAILED", "RESULT")
            
        # Test 3: Get server status
        self.log("Test 3: Getting server status", "TEST")
        response = self.send_command("get_status")
        if response and ("status" in response):
            tests_passed += 1
            self.log("Test 3: PASSED", "RESULT")
        else:
            tests_failed += 1
            self.log("Test 3: FAILED", "RESULT")
            
        # Test 4: Get server capabilities
        self.log("Test 4: Getting server capabilities", "TEST")
        response = self.send_command("get_capabilities")
        if response:
            tests_passed += 1
            self.log("Test 4: PASSED", "RESULT")
        else:
            tests_failed += 1
            self.log("Test 4: FAILED", "RESULT")
            
        # Test 5: Send invalid command
        self.log("Test 5: Sending invalid command", "TEST")
        response = self.send_command("invalid_command_test")
        if response and ("error" in response or "status" in response and response["status"] == "error"):
            tests_passed += 1
            self.log("Test 5: PASSED", "RESULT")
        else:
            tests_failed += 1
            self.log("Test 5: FAILED", "RESULT")
            
        # Cleanup
        self.disconnect()
        
        # Summary
        self.log(f"Tests completed: {tests_passed} passed, {tests_failed} failed", "SUMMARY")
        return (tests_passed, tests_failed)
        
    def run_custom_command(self, command, data=None):
        """Run a custom command specified by the user."""
        if not self.connected:
            if not self.connect():
                return False
                
        response = self.send_command(command, data)
        self.disconnect()
        return response


def main():
    parser = argparse.ArgumentParser(description="Test an MCP server")
    parser.add_argument("--host", default="localhost", help="MCP server hostname or IP")
    parser.add_argument("--port", type=int, default=8000, help="MCP server port")
    parser.add_argument("--timeout", type=int, default=5, help="Connection timeout in seconds")
    parser.add_argument("--command", help="Send a specific command instead of running the test suite")
    parser.add_argument("--data", help="JSON data to send with the command")
    
    args = parser.parse_args()
    
    tester = MCPServerTester(args.host, args.port, args.timeout)
    
    if args.command:
        data = None
        if args.data:
            try:
                data = json.loads(args.data)
            except json.JSONDecodeError:
                print("Error: Invalid JSON data format")
                return 1
                
        if tester.connect():
            tester.run_custom_command(args.command, data)
            tester.disconnect()
    else:
        test_results = tester.run_basic_tests()
        if test_results[1] > 0:  # If any tests failed
            return 1
            
    return 0


if __name__ == "__main__":
    sys.exit(main())
